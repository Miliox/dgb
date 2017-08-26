import memory;

import std.stdio;
import core.bitop;

align(2):
union AF {
    align(1):
    struct {
        ubyte f;
        ubyte a;
    }
    ushort v;
};

align(2):
union BC {
    align(1):
    struct {
        ubyte c;
        ubyte b;
    }
    ushort v;
};

align(2):
union DE {
    align(1):
    struct {
        ubyte e;
        ubyte d;
    }
    ushort v;
};

align(2):
union HL {
    align(1):
    struct {
        ubyte l;
        ubyte h;
    }
    ushort v;
};

static struct Registers
{
    AF af;
    BC bc;
    DE de;
    HL hl;
    ushort sp;  // special
    ushort pc;  // program counter

    unittest {
        Registers r;
        r.af.v = 0xDEAD;
        r.bc.v = 0xABCD;
        r.hl.h = 0xFF;
        r.hl.l = 0x00;

        assert(r.af.a == 0xDE);
        assert(r.af.f == 0xAD);
        assert(r.bc.b == 0xAB);
        assert(r.bc.c == 0xCD);
        assert(r.hl.v == 0xFF00);
    }
}

class Cpu
{
    private Registers r;

    // interrupt master enable flag
    private bool ime = false;

    // disable interrupt requested by DI (must disable ime after execute next instruction)
    private bool diRequested = false;

    // enable interrupt requested by EI (must enable ime after execute next instruction)
    private bool eiRequested = false;

    private bool stopped = false;
    private bool halted  = false;

    Memory memory;

    // flags
    private static immutable ubyte FLAG_ZERO  = 1 << 7; // zero flag
    private static immutable ubyte FLAG_NEG   = 1 << 6; // add-sub flag (bcd)
    private static immutable ubyte FLAG_HALF  = 1 << 5; // half carry flag (bcd)
    private static immutable ubyte FLAG_CARRY = 1 << 4; // carry flag

    // instruction set architecture
    private ubyte delegate()[256] isaTable; // Instruction Set Architecture
    private ubyte delegate()[256] cbeTable; // CB Extensions Set

    this()
    {
        clear();
        fillIsa();
        fillCbe();

        memory = new NoMemory();
    }

    ubyte step()
    {
        // fetch
        ubyte opcode = read8(r.pc++);

        // decode
        auto f = isaTable[opcode];

        // execute
        auto ticks = f();

        return ticks;
    }

    void clear()
    {
        r.af.v = 0;
        r.bc.v = 0;
        r.de.v = 0;
        r.hl.v = 0;
        r.sp = 0;
        r.pc = 0;
    }

    // Helpers

    private ubyte read8(ushort addr) {
        return memory.read8(addr);
    }

    private ushort read16(ushort addr) {
        ubyte lsb = memory.read8(addr++);
        ubyte msb = memory.read8(addr);
        return (msb << 8) + lsb;
    }

    private void write8(ushort addr, ubyte value) {
        memory.write8(addr, value);
    }

    private void write16(ushort addr, ushort value) {
        ubyte lsb = value & 0xff;
        ubyte msb = (value >> 8) & 0xff;
        memory.write8(addr++, lsb);
        memory.write8(addr, msb);
    }

    void fillIsa()
    {
        // TODO: Populate ISA Table

        // NOP
        isaTable[0x00] = delegate() {
            return ubyte(4);
        };

        // LD BC,d16
        isaTable[0x01] = delegate() {
            r.bc.v = read16(r.pc);
            r.pc += 2;
            return ubyte(12);
        };

        // LD (BC),A
        isaTable[0x02] = delegate() {
            write8(r.bc.v, r.af.a);
            return ubyte(8);
        };

        // INC BC
        isaTable[0x03] = delegate() {
            inc16(r.bc.v);
            return ubyte(8);
        };

        // INC B
        isaTable[0x04] = delegate() {
            inc8(r.bc.b, r.af.f);
            return ubyte(4);
        };

        // DEC B
        isaTable[0x05] = delegate() {
            dec8(r.bc.b, r.af.f);
            return ubyte(4);
        };

        // LD B,d8
        isaTable[0x06] = delegate() {
            r.bc.b = read8(r.pc);
            r.pc += 1;
            return ubyte(8);
        };

        // RLCA
        isaTable[0x07] = delegate() {
            rlc8(r.af.a, r.af.f);
            setFlag(r.af.f, FLAG_ZERO | FLAG_NEG | FLAG_HALF , false);
            return ubyte(4);
        };

        // LD (a16),SP
        isaTable[0x08] = delegate() {
            write16(read16(r.pc), r.sp);
            r.pc += 2;
            return ubyte(20);
        };

        // ADD HL,BC
        isaTable[0x09] = delegate() {
            add16(r.hl.v, r.bc.v, r.af.f);
            return ubyte(8);
        };

        // LD A,(BC)
        isaTable[0x0a] = delegate() {
            r.af.a = read8(r.bc.v);
            return ubyte(8);
        };

        // DEC BC
        isaTable[0x0b] = delegate() {
            dec16(r.bc.v);
            return ubyte(8);
        };

        // INC C
        isaTable[0x0c] = delegate() {
            inc8(r.bc.c, r.af.f);
            return ubyte(4);
        };

        // DEC C
        isaTable[0x0d] = delegate() {
            dec8(r.bc.c, r.af.f);
            return ubyte(4);
        };

        // LD C,d8
        isaTable[0x0e] = delegate() {
            r.bc.c = read8(r.pc);
            r.pc += 1;
            return ubyte(8);
        };

        // RRCA
        isaTable[0x0f] = delegate() {
            rrc8(r.af.a, r.af.f);
            setFlag(r.af.f, FLAG_ZERO | FLAG_NEG | FLAG_HALF , false);
            return ubyte(4);
        };

        // STOP
        isaTable[0x10] = delegate() {
            ubyte arg = read8(r.pc++);
            assert(arg == 0);
            stopped = true;
            return ubyte(4);
        };

        // LD DE,d16
        isaTable[0x11] = delegate() {
            r.de.v = read16(r.pc);
            r.pc += 2;
            return ubyte(12);
        };

        // LD (DE),A
        isaTable[0x12] = delegate() {
            write8(r.de.v, r.af.a);
            return ubyte(8);
        };

        // INC DE
        isaTable[0x13] = delegate() {
            inc16(r.de.v);
            return ubyte(8);
        };

        // INC D
        isaTable[0x14] = delegate() {
            inc8(r.de.d, r.af.f);
            return ubyte(4);
        };

        // DEC D
        isaTable[0x15] = delegate() {
            dec8(r.de.d, r.af.f);
            return ubyte(4);
        };

        // LD D,d8
        isaTable[0x16] = delegate() {
            r.de.d = read8(r.pc++);
            return ubyte(8);
        };

        // RLA
        isaTable[0x17] = delegate() {
            rl8(r.af.a, r.af.f);
            setFlag(r.af.f, FLAG_ZERO | FLAG_NEG | FLAG_HALF , false);
            return ubyte(4);
        };

        // JR r8
        isaTable[0x18] = delegate() {
            byte offset = cast(byte) read8(r.pc++);
            jr(offset);
            return ubyte(12);
        };

        // ADD HL,DE
        isaTable[0x19] = delegate() {
            add16(r.hl.v, r.de.v, r.af.f);
            return ubyte(8);
        };

        // LD A,(DE)
        isaTable[0x1a] = delegate() {
            r.af.a = read8(r.de.v);
            return ubyte(8);
        };

        // DEC DE
        isaTable[0x1b] = delegate() {
            dec16(r.de.v);
            return ubyte(8);
        };

        // INC E
        isaTable[0x1c] = delegate() {
            inc8(r.de.e, r.af.f);
            return ubyte(4);
        };

        // DEC E
        isaTable[0x1d] = delegate() {
            dec8(r.de.e, r.af.f);
            return ubyte(4);
        };

        // LD E,d8
        isaTable[0x1e] = delegate() {
            r.de.e = read8(r.pc++);
            return ubyte(8);
        };

        // RRA
        isaTable[0x1f] = delegate() {
            rr8(r.af.a, r.af.f);
            setFlag(r.af.f, FLAG_ZERO | FLAG_NEG | FLAG_HALF, false);
            return ubyte(4);
        };

        // JR NZ,r8
        isaTable[0x20] = delegate() {
            byte offset = cast(byte) read8(r.pc++);
            if ((r.af.f & FLAG_ZERO) == 0) {
                jr(offset);
                return ubyte(12);
            }
            return ubyte(8);
        };

        // LD HL,d16
        isaTable[0x21] = delegate() {
            r.hl.v = read16(r.pc);
            r.pc += 2;
            return ubyte(8);
        };

        // LD (HL+),A
        isaTable[0x22] = delegate() {
            write8(r.hl.v++, r.af.a);
            return ubyte(12);
        };

        // INC HL
        isaTable[0x23] = delegate() {
            inc16(r.hl.v);
            return ubyte(8);
        };

        // INC H
        isaTable[0x24] = delegate() {
            inc8(r.hl.h, r.af.f);
            return ubyte(8);
        };

        // DEC H
        isaTable[0x25] = delegate() {
            dec8(r.hl.h, r.af.f);
            return ubyte(8);
        };

        // LD H,d8
        isaTable[0x26] = delegate() {
            r.hl.h = read8(r.pc++);
            return ubyte(8);
        };

        // DAA
        isaTable[0x27] = delegate() {
            daa8(r.af.a, r.af.f);
            return ubyte(4);
        };

        // JR Z,r8
        isaTable[0x28] = delegate() {
            byte offset = cast(byte) read8(r.pc++);
            if ((r.af.f & FLAG_ZERO) != 0) {
                jr(offset);
                return ubyte(12);
            }
            return ubyte(8);
        };

        // ADD HL,HL
        isaTable[0x29] = delegate() {
            add16(r.hl.v, r.hl.v, r.af.f);
            return ubyte(8);
        };

        // LD A,(HL+)
        isaTable[0x2a] = delegate() {
            r.af.a = read8(r.hl.v++);
            return ubyte(8);
        };

        // DEC HL
        isaTable[0x2b] = delegate() {
            dec16(r.hl.v);
            return ubyte(8);
        };

        // INC L
        isaTable[0x2c] = delegate() {
            inc8(r.hl.l, r.af.f);
            return ubyte(4);
        };

        // DEC L
        isaTable[0x2d] = delegate() {
            dec8(r.hl.l, r.af.f);
            return ubyte(4);
        };

        // LD L,d8
        isaTable[0x2e] = delegate() {
            r.hl.l = read8(r.pc++);
            return ubyte(8);
        };

        // CPL
        isaTable[0x2f] = delegate() {
            cpl8(r.af.a, r.af.f);
            return ubyte(8);
        };

        // JR NC,r8
        isaTable[0x30] = delegate() {
            byte offset = cast(byte) read8(r.pc++);
            if ((r.af.f & FLAG_CARRY) == 0) {
                jr(offset);
                return ubyte(12);
            }
            return ubyte(8);
        };

        // LD SP,d16
        isaTable[0x31] = delegate() {
            r.sp = read16(r.pc);
            r.pc += 2;
            return ubyte(12);
        };

        // LD (HL-),A
        isaTable[0x32] = delegate() {
            write8(r.hl.v--, r.af.a);
            return ubyte(8);
        };

        // INC SP
        isaTable[0x33] = delegate() {
            inc16(r.sp);
            return ubyte(8);
        };

        // INC (HL)
        isaTable[0x34] = delegate() {
            ubyte v = read8(r.hl.v);
            inc8(v, r.af.f);
            write(r.hl.v, v);
            return ubyte(12);
        };

        // DEC (HL)
        isaTable[0x35] = delegate() {
            ubyte v = read8(r.hl.v);
            dec8(v, r.af.f);
            write(r.hl.v, v);
            return ubyte(12);
        };

        // LD (HL),d8
        isaTable[0x36] = delegate() {
            ubyte arg = read8(r.pc++);
            write8(r.hl.v, arg);
            return ubyte(12);
        };

        // SCF
        isaTable[0x37] = delegate() {
            scf(r.af.f);
            return ubyte(4);
        };

        // JR C,r8
        isaTable[0x38] = delegate() {
            byte offset = cast(byte) read8(r.pc++);
            if ((r.af.f & FLAG_CARRY) != 0) {
                jr(offset);
                return ubyte(12);
            }
            return ubyte(8);
        };

        // ADD HL,SP
        isaTable[0x39] = delegate() {
            add16(r.hl.v, r.sp, r.af.f);
            return ubyte(8);
        };

        // LD A,(HL-)
        isaTable[0x3a] = delegate() {
            r.af.a = read8(r.hl.v--);
            return ubyte(8);
        };

        // DEC SP
        isaTable[0x3b] = delegate() {
            dec16(r.sp);
            return ubyte(8);
        };

        // INC A
        isaTable[0x3c] = delegate() {
            inc8(r.af.a, r.af.f);
            return ubyte(8);
        };

        // DEC A
        isaTable[0x3d] = delegate() {
            dec8(r.af.a, r.af.f);
            return ubyte(8);
        };

        // LD A,d8
        isaTable[0x3e] = delegate() {
            r.af.a = read8(r.pc++);
            return ubyte(8);
        };

        // CCF
        isaTable[0x3f] = delegate() {
            ccf(r.af.f);
            return ubyte(4);
        };

        // LD B,B
        isaTable[0x40] = delegate() {
            // r.bc.b = r.bc.b;
            return ubyte(4);
        };

        // LD B,C
        isaTable[0x41] = delegate() {
            r.bc.b = r.bc.c;
            return ubyte(4);
        };

        // LD B,D
        isaTable[0x42] = delegate() {
            r.bc.b = r.de.d;
            return ubyte(4);
        };

        // LD B,E
        isaTable[0x43] = delegate() {
            r.bc.b = r.de.e;
            return ubyte(4);
        };

        // LD B,H
        isaTable[0x44] = delegate() {
            r.bc.b = r.hl.h;
            return ubyte(4);
        };

        // LD B,L
        isaTable[0x45] = delegate() {
            r.bc.b = r.hl.l;
            return ubyte(4);
        };

        // LD B,(HL)
        isaTable[0x46] = delegate() {
            r.bc.b = read8(r.hl.v);
            return ubyte(8);
        };

        // LD B,A
        isaTable[0x47] = delegate() {
            r.bc.b = r.af.a;
            return ubyte(4);
        };

        // LD C,B
        isaTable[0x48] = delegate() {
            r.bc.c = r.bc.b;
            return ubyte(4);
        };

        // LD C,C
        isaTable[0x49] = delegate() {
            // r.bc.c = r.bc.c;
            return ubyte(4);
        };

        // LD C,D
        isaTable[0x4a] = delegate() {
            r.bc.c = r.de.d;
            return ubyte(4);
        };

        // LD C,E
        isaTable[0x4b] = delegate() {
            r.bc.c = r.de.e;
            return ubyte(4);
        };

        // LD C,H
        isaTable[0x4c] = delegate() {
            r.bc.c = r.hl.h;
            return ubyte(4);
        };

        // LD C,L
        isaTable[0x4d] = delegate() {
            r.bc.c = r.hl.l;
            return ubyte(4);
        };

        // LD C,(HL)
        isaTable[0x4e] = delegate() {
            r.bc.c = read8(r.hl.v);
            return ubyte(8);
        };

        // LD C,A
        isaTable[0x4f] = delegate() {
            r.bc.c = r.af.a;
            return ubyte(4);
        };

        // LD D,B
        isaTable[0x50] = delegate() {
            r.de.d = r.bc.b;
            return ubyte(4);
        };

        // LD D,C
        isaTable[0x51] = delegate() {
            r.de.d = r.bc.c;
            return ubyte(4);
        };

        // LD D,D
        isaTable[0x52] = delegate() {
            // r.de.d = r.de.d;
            return ubyte(4);
        };

        // LD D,E
        isaTable[0x53] = delegate() {
            r.de.d = r.de.e;
            return ubyte(4);
        };

        // LD D,H
        isaTable[0x54] = delegate() {
            r.de.d = r.hl.h;
            return ubyte(4);
        };

        // LD D,L
        isaTable[0x55] = delegate() {
            r.de.d = r.hl.l;
            return ubyte(4);
        };

        // LD D,(HL)
        isaTable[0x56] = delegate() {
            r.de.d = read8(r.hl.v);
            return ubyte(8);
        };

        // LD D,A
        isaTable[0x57] = delegate() {
            r.de.d = r.af.a;
            return ubyte(4);
        };

        // LD E,B
        isaTable[0x58] = delegate() {
            r.de.e = r.bc.b;
            return ubyte(4);
        };

        // LD E,C
        isaTable[0x59] = delegate() {
            r.de.e = r.bc.c;
            return ubyte(4);
        };

        // LD E,D
        isaTable[0x5a] = delegate() {
            r.de.e = r.de.d;
            return ubyte(4);
        };

        // LD E,E
        isaTable[0x5b] = delegate() {
            // r.de.e = r.de.e;
            return ubyte(4);
        };

        // LD E,H
        isaTable[0x5c] = delegate() {
            r.de.e = r.hl.h;
            return ubyte(4);
        };

        // LD E,L
        isaTable[0x5d] = delegate() {
            r.de.e = r.hl.l;
            return ubyte(4);
        };

        // LD E,(HL)
        isaTable[0x5e] = delegate() {
            r.de.e = read8(r.hl.v);
            return ubyte(8);
        };

        // LD E,A
        isaTable[0x5f] = delegate() {
            r.de.e = r.af.a;
            return ubyte(4);
        };

        // LD H,B
        isaTable[0x60] = delegate() {
            r.hl.h = r.bc.b;
            return ubyte(4);
        };

        // LD H,C
        isaTable[0x61] = delegate() {
            r.hl.h = r.bc.c;
            return ubyte(4);
        };

        // LD H,D
        isaTable[0x62] = delegate() {
            r.hl.h = r.de.d;
            return ubyte(4);
        };

        // LD H,E
        isaTable[0x63] = delegate() {
            r.hl.h = r.de.e;
            return ubyte(4);
        };

        // LD H,H
        isaTable[0x64] = delegate() {
            // r.hl.h = r.hl.h;
            return ubyte(4);
        };

        // LD H,L
        isaTable[0x65] = delegate() {
            r.hl.h = r.hl.l;
            return ubyte(4);
        };

        // LD H,(HL)
        isaTable[0x66] = delegate() {
            r.hl.h = read8(r.hl.v);
            return ubyte(8);
        };

        // LD H,A
        isaTable[0x67] = delegate() {
            r.hl.h = r.af.a;
            return ubyte(4);
        };

        // LD L,B
        isaTable[0x68] = delegate() {
            r.hl.l = r.bc.b;
            return ubyte(4);
        };

        // LD L,C
        isaTable[0x69] = delegate() {
            r.hl.l = r.bc.c;
            return ubyte(4);
        };

        // LD L,D
        isaTable[0x6a] = delegate() {
            r.hl.l = r.de.d;
            return ubyte(4);
        };

        // LD L,E
        isaTable[0x6b] = delegate() {
            r.hl.l = r.de.e;
            return ubyte(4);
        };

        // LD L,H
        isaTable[0x6c] = delegate() {
            r.hl.l = r.hl.h;
            return ubyte(4);
        };

        // LD L,L
        isaTable[0x6d] = delegate() {
            // r.hl.l = r.hl.l;
            return ubyte(4);
        };

        // LD L,(HL)
        isaTable[0x6e] = delegate() {
            r.hl.l = read8(r.hl.v);
            return ubyte(8);
        };

        // LD L,A
        isaTable[0x6f] = delegate() {
            r.hl.l = r.af.a;
            return ubyte(4);
        };

        // LD (HL),B
        isaTable[0x70] = delegate() {
            write8(r.hl.v, r.bc.b);
            return ubyte(8);
        };

        // LD (HL),C
        isaTable[0x71] = delegate() {
            write8(r.hl.v, r.bc.c);
            return ubyte(8);
        };

        // LD (HL),D
        isaTable[0x72] = delegate() {
            write8(r.hl.v, r.de.d);
            return ubyte(8);
        };

        // LD (HL),E
        isaTable[0x73] = delegate() {
            write8(r.hl.v, r.de.e);
            return ubyte(8);
        };

        // LD (HL),H
        isaTable[0x74] = delegate() {
            write8(r.hl.v, r.hl.h);
            return ubyte(8);
        };

        // LD (HL),L
        isaTable[0x75] = delegate() {
            write8(r.hl.v, r.hl.l);
            return ubyte(8);
        };

        // HALT
        isaTable[0x76] = delegate() {
            halted = true;
            return ubyte(8);
        };

        // LD (HL),A
        isaTable[0x77] = delegate() {
            write8(r.hl.v, r.af.a);
            return ubyte(4);
        };

        // LD A,B
        isaTable[0x78] = delegate() {
            r.af.a = r.bc.b;
            return ubyte(4);
        };

        // LD A,C
        isaTable[0x79] = delegate() {
            r.af.a = r.bc.c;
            return ubyte(4);
        };

        // LD A,D
        isaTable[0x7a] = delegate() {
            r.af.a = r.de.d;
            return ubyte(4);
        };

        // LD A,E
        isaTable[0x7b] = delegate() {
            r.af.a = r.de.e;
            return ubyte(4);
        };

        // LD A,H
        isaTable[0x7c] = delegate() {
            r.af.a = r.hl.h;
            return ubyte(4);
        };

        // LD A,L
        isaTable[0x7d] = delegate() {
            r.af.a = r.hl.l;
            return ubyte(4);
        };

        // LD A,(HL)
        isaTable[0x7e] = delegate() {
            r.af.a = read8(r.hl.v);
            return ubyte(8);
        };

        // LD A,A
        isaTable[0x7f] = delegate() {
            // r.af.a = r.af.a;
            return ubyte(4);
        };

        // ADD A,B
        isaTable[0x80] = delegate() {
            add8(r.af.a, r.bc.b, r.af.f);
            return ubyte(4);
        };

        // ADD A,C
        isaTable[0x81] = delegate() {
            add8(r.af.a, r.bc.c, r.af.f);
            return ubyte(4);
        };

        // ADD A,D
        isaTable[0x82] = delegate() {
            add8(r.af.a, r.de.d, r.af.f);
            return ubyte(4);
        };

        // ADD A,E
        isaTable[0x83] = delegate() {
            add8(r.af.a, r.de.e, r.af.f);
            return ubyte(4);
        };

        // ADD A,H
        isaTable[0x84] = delegate() {
            add8(r.af.a, r.hl.h, r.af.f);
            return ubyte(4);
        };

        // ADD A,L
        isaTable[0x85] = delegate() {
            add8(r.af.a, r.hl.l, r.af.f);
            return ubyte(4);
        };

        // ADD A,(HL)
        isaTable[0x86] = delegate() {
            ubyte v = read8(r.hl.v);
            add8(r.af.a, v, r.af.f);
            return ubyte(8);
        };

        // ADD A,A
        isaTable[0x87] = delegate() {
            add8(r.af.a, r.af.a, r.af.f);
            return ubyte(4);
        };

        // ADC A,B
        isaTable[0x88] = delegate() {
            adc8(r.af.a, r.bc.b, r.af.f);
            return ubyte(4);
        };

        // ADC A,C
        isaTable[0x89] = delegate() {
            adc8(r.af.a, r.bc.c, r.af.f);
            return ubyte(4);
        };

        // ADC A,D
        isaTable[0x8a] = delegate() {
            adc8(r.af.a, r.de.d, r.af.f);
            return ubyte(4);
        };

        // ADC A,E
        isaTable[0x8b] = delegate() {
            adc8(r.af.a, r.de.e, r.af.f);
            return ubyte(4);
        };

        // ADC A,H
        isaTable[0x8c] = delegate() {
            adc8(r.af.a, r.hl.h, r.af.f);
            return ubyte(4);
        };

        // ADC A,L
        isaTable[0x8d] = delegate() {
            adc8(r.af.a, r.hl.l, r.af.f);
            return ubyte(4);
        };

        // ADC A,(HL)
        isaTable[0x8e] = delegate() {
            ubyte v = read8(r.hl.v);
            adc8(r.af.a, v, r.af.f);
            return ubyte(8);
        };

        // ADC A,A
        isaTable[0x8f] = delegate() {
            adc8(r.af.a, r.af.a, r.af.f);
            return ubyte(4);
        };

        // SUB A,B
        isaTable[0x90] = delegate() {
            sub8(r.af.a, r.bc.b, r.af.f);
            return ubyte(4);
        };

        // SUB A,C
        isaTable[0x91] = delegate() {
            sub8(r.af.a, r.bc.c, r.af.f);
            return ubyte(4);
        };

        // SUB A,D
        isaTable[0x92] = delegate() {
            sub8(r.af.a, r.de.d, r.af.f);
            return ubyte(4);
        };

        // SUB A,E
        isaTable[0x93] = delegate() {
            sub8(r.af.a, r.de.e, r.af.f);
            return ubyte(4);
        };

        // SUB A,H
        isaTable[0x94] = delegate() {
            sub8(r.af.a, r.hl.h, r.af.f);
            return ubyte(4);
        };

        // SUB A,L
        isaTable[0x95] = delegate() {
            sub8(r.af.a, r.hl.l, r.af.f);
            return ubyte(4);
        };

        // SUB A,(HL)
        isaTable[0x96] = delegate() {
            ubyte v = read8(r.hl.v);
            sub8(r.af.a, v, r.af.f);
            return ubyte(8);
        };

        // SUB A,A
        isaTable[0x97] = delegate() {
            sub8(r.af.a, r.af.a, r.af.f);
            return ubyte(4);
        };

        // SBC A,B
        isaTable[0x98] = delegate() {
            sbc8(r.af.a, r.bc.b, r.af.f);
            return ubyte(4);
        };

        // SBC A,C
        isaTable[0x99] = delegate() {
            sbc8(r.af.a, r.bc.c, r.af.f);
            return ubyte(4);
        };

        // SBC A,D
        isaTable[0x9a] = delegate() {
            sbc8(r.af.a, r.de.d, r.af.f);
            return ubyte(4);
        };

        // SBC A,E
        isaTable[0x9b] = delegate() {
            sbc8(r.af.a, r.de.e, r.af.f);
            return ubyte(4);
        };

        // SBC A,H
        isaTable[0x9c] = delegate() {
            sbc8(r.af.a, r.hl.h, r.af.f);
            return ubyte(4);
        };

        // SBC A,L
        isaTable[0x9d] = delegate() {
            sbc8(r.af.a, r.hl.l, r.af.f);
            return ubyte(4);
        };

        // SBC A,(HL)
        isaTable[0x9e] = delegate() {
            ubyte v = read8(r.hl.v);
            sbc8(r.af.a, v, r.af.f);
            return ubyte(8);
        };

        // SBC A,A
        isaTable[0x9f] = delegate() {
            sbc8(r.af.a, r.af.a, r.af.f);
            return ubyte(4);
        };

        // AND A,B
        isaTable[0xa0] = delegate() {
            and8(r.af.a, r.bc.b, r.af.f);
            return ubyte(4);
        };

        // AND A,C
        isaTable[0xa1] = delegate() {
            and8(r.af.a, r.bc.c, r.af.f);
            return ubyte(4);
        };

        // AND A,D
        isaTable[0xa2] = delegate() {
            and8(r.af.a, r.de.d, r.af.f);
            return ubyte(4);
        };

        // AND A,E
        isaTable[0xa3] = delegate() {
            and8(r.af.a, r.de.e, r.af.f);
            return ubyte(4);
        };

        // AND A,H
        isaTable[0xa4] = delegate() {
            and8(r.af.a, r.hl.h, r.af.f);
            return ubyte(4);
        };

        // AND A,L
        isaTable[0xa5] = delegate() {
            and8(r.af.a, r.hl.l, r.af.f);
            return ubyte(4);
        };

        // AND A,(HL)
        isaTable[0xa6] = delegate() {
            ubyte v = read8(r.hl.v);
            and8(r.af.a, v, r.af.f);
            return ubyte(8);
        };

        // AND A,A
        isaTable[0xa7] = delegate() {
            and8(r.af.a, r.af.a, r.af.f);
            return ubyte(4);
        };

        // XOR A,B
        isaTable[0xa8] = delegate() {
            xor8(r.af.a, r.bc.b, r.af.f);
            return ubyte(4);
        };

        // XOR A,C
        isaTable[0xa9] = delegate() {
            xor8(r.af.a, r.bc.c, r.af.f);
            return ubyte(4);
        };

        // XOR A,D
        isaTable[0xaa] = delegate() {
            xor8(r.af.a, r.de.d, r.af.f);
            return ubyte(4);
        };

        // XOR A,E
        isaTable[0xab] = delegate() {
            xor8(r.af.a, r.de.e, r.af.f);
            return ubyte(4);
        };

        // XOR A,H
        isaTable[0xac] = delegate() {
            xor8(r.af.a, r.hl.h, r.af.f);
            return ubyte(4);
        };

        // XOR A,L
        isaTable[0xad] = delegate() {
            xor8(r.af.a, r.hl.l, r.af.f);
            return ubyte(4);
        };

        // XOR A,(HL)
        isaTable[0xae] = delegate() {
            ubyte v = read8(r.hl.v);
            xor8(r.af.a, v, r.af.f);
            return ubyte(8);
        };

        // XOR A,A
        isaTable[0xaf] = delegate() {
            xor8(r.af.a, r.af.a, r.af.f);
            return ubyte(4);
        };

        //

        // OR A,B
        isaTable[0xb0] = delegate() {
            or8(r.af.a, r.bc.b, r.af.f);
            return ubyte(4);
        };

        // OR A,C
        isaTable[0xb1] = delegate() {
            or8(r.af.a, r.bc.c, r.af.f);
            return ubyte(4);
        };

        // OR A,D
        isaTable[0xb2] = delegate() {
            or8(r.af.a, r.de.d, r.af.f);
            return ubyte(4);
        };

        // OR A,E
        isaTable[0xb3] = delegate() {
            or8(r.af.a, r.de.e, r.af.f);
            return ubyte(4);
        };

        // OR A,H
        isaTable[0xb4] = delegate() {
            or8(r.af.a, r.hl.h, r.af.f);
            return ubyte(4);
        };

        // OR A,L
        isaTable[0xb5] = delegate() {
            or8(r.af.a, r.hl.l, r.af.f);
            return ubyte(4);
        };

        // OR A,(HL)
        isaTable[0xb6] = delegate() {
            ubyte v = read8(r.hl.v);
            or8(r.af.a, v, r.af.f);
            return ubyte(8);
        };

        // OR A,A
        isaTable[0xb7] = delegate() {
            or8(r.af.a, r.af.a, r.af.f);
            return ubyte(4);
        };

        // CP A,B
        isaTable[0xb8] = delegate() {
            cp8(r.af.a, r.bc.b, r.af.f);
            return ubyte(4);
        };

        // CP A,C
        isaTable[0xb9] = delegate() {
            cp8(r.af.a, r.bc.c, r.af.f);
            return ubyte(4);
        };

        // CP A,D
        isaTable[0xba] = delegate() {
            cp8(r.af.a, r.de.d, r.af.f);
            return ubyte(4);
        };

        // CP A,E
        isaTable[0xbb] = delegate() {
            cp8(r.af.a, r.de.e, r.af.f);
            return ubyte(4);
        };

        // CP A,H
        isaTable[0xbc] = delegate() {
            cp8(r.af.a, r.hl.h, r.af.f);
            return ubyte(4);
        };

        // CP A,L
        isaTable[0xbd] = delegate() {
            cp8(r.af.a, r.hl.l, r.af.f);
            return ubyte(4);
        };

        // CP A,(HL)
        isaTable[0xbe] = delegate() {
            ubyte v = read8(r.hl.v);
            cp8(r.af.a, v, r.af.f);
            return ubyte(8);
        };

        // CP A,A
        isaTable[0xbf] = delegate() {
            cp8(r.af.a, r.af.a, r.af.f);
            return ubyte(4);
        };

        // RET NZ
        isaTable[0xc0] = delegate() {
            if ((r.af.f & FLAG_ZERO) == 0) {
                ret();
                return ubyte(20);
            }
            return ubyte(8);
        };

        // POP BC
        isaTable[0xc1] = delegate() {
            pop(r.bc.v);
            return ubyte(12);
        };

        // JP NZ,a16
        isaTable[0xc2] = delegate() {
            ushort addr = read16(r.pc);
            r.pc += 2;

            if ((r.af.f & FLAG_ZERO) == 0) {
                jp(addr);
                return ubyte(16);
            }
            return ubyte(12);
        };

        // JP a16
        isaTable[0xc3] = delegate() {
            jp(read16(r.pc));
            return ubyte(16);
        };

        // CALL NZ,a16
        isaTable[0xc4] = delegate() {
            ushort addr = read16(r.pc);
            r.pc += 2;

            if ((r.af.f & FLAG_ZERO) == 0) {
                call(addr);
                return ubyte(16);
            }
            return ubyte(12);
        };

        // PUSH BC
        isaTable[0xc5] = delegate() {
            push(r.bc.v);
            return ubyte(16);
        };

        // ADD A,d8
        isaTable[0xc6] = delegate() {
            ubyte v = read8(r.pc++);
            add8(r.af.a, v, r.af.f);
            return ubyte(8);
        };

        // RST 00H
        isaTable[0xc7] = delegate() {
            rst(0x00);
            return ubyte(16);
        };

        // RET Z
        isaTable[0xc8] = delegate() {
            if ((r.af.f & FLAG_ZERO) != 0) {
                ret();
                return ubyte(20);
            }
            return ubyte(8);
        };

        // RET
        isaTable[0xc9] = delegate() {
            ret();
            return ubyte(16);
        };

        // JP Z,a16
        isaTable[0xca] = delegate() {
            ushort addr = read16(r.pc);
            r.pc += 2;

            if ((r.af.f & FLAG_ZERO) != 0) {
                jp(addr);
                return ubyte(16);
            }
            return ubyte(12);
        };

        // PREFIX CB
        isaTable[0xcb] = delegate() {
            ubyte opcode = read8(r.pc++);
            return cast(ubyte) (4 + cbeTable[opcode]());
        };

        // CALL Z,a16
        isaTable[0xcc] = delegate() {
            ushort addr = read16(r.pc);
            r.pc += 2;

            if ((r.af.f & FLAG_ZERO) != 0) {
                call(addr);
                return ubyte(16);
            }
            return ubyte(12);
        };

        // CALL a16
        isaTable[0xcd] = delegate() {
            ushort addr = read16(r.pc);
            r.pc += 2;
            call(addr);
            return ubyte(24);
        };

        // ADC A,d8
        isaTable[0xce] = delegate() {
            ubyte v = read8(r.pc++);
            adc8(r.af.a, v, r.af.f);
            return ubyte(8);
        };

        // RST 08H
        isaTable[0xcf] = delegate() {
            rst(0x08);
            return ubyte(16);
        };

        // RET NC
        isaTable[0xd0] = delegate() {
            if ((r.af.f & FLAG_CARRY) == 0) {
                ret();
                return ubyte(20);
            }
            return ubyte(8);
        };

        // POP DE
        isaTable[0xd1] = delegate() {
            pop(r.de.v);
            return ubyte(12);
        };

        // JP NC,a16
        isaTable[0xd2] = delegate() {
            ushort addr = read16(r.pc);
            r.pc += 2;

            if ((r.af.f & FLAG_CARRY) == 0) {
                jp(addr);
                return ubyte(16);
            }
            return ubyte(12);
        };

        isaTable[0xd3] = delegate() {
            throw new Exception("No instruction associated with OPCODE D3");
        };

        // CALL NC,a16
        isaTable[0xd4] = delegate() {
            ushort addr = read16(r.pc);
            r.pc += 2;

            if ((r.af.f & FLAG_CARRY) == 0) {
                call(addr);
                return ubyte(16);
            }
            return ubyte(12);
        };

        // PUSH DE
        isaTable[0xd5] = delegate() {
            push(r.de.v);
            return ubyte(16);
        };

        // SUB d8
        isaTable[0xd6] = delegate() {
            ubyte v = read8(r.pc++);
            sub8(r.af.a, v, r.af.f);
            return ubyte(8);
        };

        // RST 10H
        isaTable[0xd7] = delegate() {
            rst(0x10);
            return ubyte(16);
        };

        // RET C
        isaTable[0xd8] = delegate() {
            if ((r.af.f & FLAG_CARRY) != 0) {
                ret();
                return ubyte(20);
            }
            return ubyte(8);
        };

        // RETI
        isaTable[0xd9] = delegate() {
            ret();
            ime = true;
            return ubyte(16);
        };

        // JP C,a16
        isaTable[0xda] = delegate() {
            ushort addr = read16(r.pc);
            r.pc += 2;

            if ((r.af.f & FLAG_CARRY) != 0) {
                jp(addr);
                return ubyte(16);
            }
            return ubyte(12);
        };

        isaTable[0xdb] = delegate() {
            throw new Exception("No instruction associated with OPCODE DB");
        };

        // CALL C,a16
        isaTable[0xdc] = delegate() {
            ushort addr = read16(r.pc);
            r.pc += 2;

            if ((r.af.f & FLAG_CARRY) != 0) {
                call(addr);
                return ubyte(16);
            }
            return ubyte(12);
        };

        isaTable[0xdd] = delegate() {
            throw new Exception("No instruction associated with OPCODE DD");
        };

        // SBC A,d8
        isaTable[0xde] = delegate() {
            ubyte v = read8(r.pc++);
            sbc8(r.af.a, v, r.af.f);
            return ubyte(8);
        };

        // RST 18H
        isaTable[0xdf] = delegate() {
            rst(0x18);
            return ubyte(16);
        };

        // LDH (a8),A
        isaTable[0xe0] = delegate() {
            ubyte offset = read8(r.pc++);
            write8(0xff00 + offset, r.af.a);
            return ubyte(12);
        };

        // POP HL
        isaTable[0xe1] = delegate() {
            pop(r.hl.v);
            return ubyte(12);
        };

        // LD (C),A
        isaTable[0xe2] = delegate() {
            write8(0xff00 + r.bc.c, r.af.f);
            return ubyte(8);
        };

        isaTable[0xe3] = delegate() {
            throw new Exception("No instruction associated with OPCODE E3");
        };

        isaTable[0xe4] = delegate() {
            throw new Exception("No instruction associated with OPCODE E4");
        };

        // PUSH HL
        isaTable[0xe5] = delegate() {
            push(r.hl.v);
            return ubyte(16);
        };

        // AND d8
        isaTable[0xe6] = delegate() {
            ubyte v = read8(r.pc++);
            and8(r.af.a, v, r.af.f);
            return ubyte(8);
        };

        // RST 20H
        isaTable[0xe7] = delegate() {
            rst(0x20);
            return ubyte(16);
        };

        // ADD SP,r8
        isaTable[0xe8] = delegate() {
            byte offset = read8(r.pc++);
            r.sp += offset;
            return ubyte(16);
        };

        // JP (HL)
        isaTable[0xe9] = delegate() {
            jp(r.hl.v);
            return ubyte(4);
        };

        // LD (a16),A
        isaTable[0xea] = delegate() {
            ushort addr = read16(r.pc);
            r.pc += 2;
            write8(addr, r.af.a);
            return ubyte(16);
        };

        isaTable[0xeb] = delegate() {
            throw new Exception("No instruction associated with OPCODE EB");
        };

        isaTable[0xec] = delegate() {
            throw new Exception("No instruction associated with OPCODE EC");
        };

        isaTable[0xed] = delegate() {
            throw new Exception("No instruction associated with OPCODE ED");
        };

        // XOR d8
        isaTable[0xee] = delegate() {
            ubyte v = read8(r.pc++);
            xor8(r.af.a, v, r.af.f);
            return ubyte(8);
        };

        // RST 28H
        isaTable[0xef] = delegate() {
            rst(0x28);
            return ubyte(16);
        };

        // LDH A,(a8)
        isaTable[0xf0] = delegate() {
            ubyte offset = read8(r.pc++);
            r.af.a = read8(0xff00 + offset);
            return ubyte(12);
        };

        // POP AF
        isaTable[0xf1] = delegate() {
            pop(r.af.v);
            return ubyte(12);
        };

        // LD A,(C)
        isaTable[0xf2] = delegate() {
            r.af.a = read8(0xff00 + r.bc.c);
            return ubyte(8);
        };

        // DI
        isaTable[0xf3] = delegate() {
            diRequested = true;
            return ubyte(4);
        };

        isaTable[0xf4] = delegate() {
            throw new Exception("No instruction associated with OPCODE F4");
        };

        // PUSH AF
        isaTable[0xf5] = delegate() {
            push(r.af.v);
            return ubyte(16);
        };

        // OR d8
        isaTable[0xf6] = delegate() {
            ubyte v = read8(r.pc++);
            or8(r.af.a, v, r.af.f);
            return ubyte(8);
        };

        // RST 30H
        isaTable[0xf7] = delegate() {
            rst(0x30);
            return ubyte(16);
        };

        // LD HL,SP+r8
        isaTable[0xf8] = delegate() {
            byte offset = read8(r.pc++);
            r.hl.v = cast(ushort) (r.sp + offset);
            return ubyte(12);
        };

        //LD SP,HL
        isaTable[0xf9] = delegate() {
            r.sp = r.hl.v;
            return ubyte(8);
        };

        // LD A,(a16)
        isaTable[0xfa] = delegate() {
            r.af.a = read8(r.pc++);
            return ubyte(16);
        };

        // EI
        isaTable[0xeb] = delegate() {
            eiRequested = true;
            return ubyte(4);
        };

        isaTable[0xec] = delegate() {
            throw new Exception("No instruction associated with OPCODE EC");
        };

        isaTable[0xed] = delegate() {
            throw new Exception("No instruction associated with OPCODE ED");
        };

        // CP d8
        isaTable[0xee] = delegate() {
            ubyte v = read8(r.pc++);
            cp8(r.af.a, v, r.af.f);
            return ubyte(8);
        };

        // RST 38H
        isaTable[0xef] = delegate() {
            rst(0x38);
            return ubyte(16);
        };
    }

    void fillCbe()
    {
        // RLC B
        cbeTable[0x00] = delegate() {
            rlc8(r.bc.b, r.af.f);
            return ubyte(8);
        };

        // RLC C
        cbeTable[0x01] = delegate() {
            rlc8(r.bc.c, r.af.f);
            return ubyte(8);
        };

        // RLC D
        cbeTable[0x02] = delegate() {
            rlc8(r.de.d, r.af.f);
            return ubyte(8);
        };

        // RLC E
        cbeTable[0x03] = delegate() {
            rlc8(r.de.e, r.af.f);
            return ubyte(8);
        };

        // RLC H
        cbeTable[0x04] = delegate() {
            rlc8(r.hl.h, r.af.f);
            return ubyte(8);
        };

        // RLC L
        cbeTable[0x05] = delegate() {
            rlc8(r.hl.l, r.af.f);
            return ubyte(8);
        };

        // RLC (HL)
        cbeTable[0x06] = delegate() {
            ubyte v = read8(r.hl.v);
            rlc8(v, r.af.f);
            write8(r.hl.v, v);
            return ubyte(8);
        };

        // RLC A
        cbeTable[0x07] = delegate() {
            rlc8(r.af.a, r.af.f);
            return ubyte(8);
        };

        // RRC B
        cbeTable[0x08] = delegate() {
            rrc8(r.bc.b, r.af.f);
            return ubyte(8);
        };

        // RRC C
        cbeTable[0x09] = delegate() {
            rrc8(r.bc.c, r.af.f);
            return ubyte(8);
        };

        // RRC D
        cbeTable[0x0a] = delegate() {
            rrc8(r.de.d, r.af.f);
            return ubyte(8);
        };

        // RRC E
        cbeTable[0x0b] = delegate() {
            rrc8(r.de.e, r.af.f);
            return ubyte(8);
        };

        // RRC H
        cbeTable[0x0c] = delegate() {
            rrc8(r.hl.h, r.af.f);
            return ubyte(8);
        };

        // RRC L
        cbeTable[0x0d] = delegate() {
            rrc8(r.hl.l, r.af.f);
            return ubyte(8);
        };

        // RRC (HL)
        cbeTable[0x0e] = delegate() {
            ubyte v = read8(r.hl.v);
            rrc8(v, r.af.f);
            write8(r.hl.v, v);
            return ubyte(8);
        };

        // RRC A
        cbeTable[0x0f] = delegate() {
            rrc8(r.af.a, r.af.f);
            return ubyte(8);
        };

        // RL B
        cbeTable[0x10] = delegate() {
            rl8(r.bc.b, r.af.f);
            return ubyte(8);
        };

        // RL C
        cbeTable[0x11] = delegate() {
            rl8(r.bc.c, r.af.f);
            return ubyte(8);
        };

        // RL D
        cbeTable[0x12] = delegate() {
            rl8(r.de.d, r.af.f);
            return ubyte(8);
        };

        // RL E
        cbeTable[0x13] = delegate() {
            rl8(r.de.e, r.af.f);
            return ubyte(8);
        };

        // RL H
        cbeTable[0x14] = delegate() {
            rl8(r.hl.h, r.af.f);
            return ubyte(8);
        };

        // RL L
        cbeTable[0x15] = delegate() {
            rl8(r.hl.l, r.af.f);
            return ubyte(8);
        };

        // RL (HL)
        cbeTable[0x16] = delegate() {
            ubyte v = read8(r.hl.v);
            rl8(v, r.af.f);
            write8(r.hl.v, v);
            return ubyte(8);
        };

        // RL A
        cbeTable[0x17] = delegate() {
            rl8(r.af.a, r.af.f);
            return ubyte(8);
        };

        // RR B
        cbeTable[0x18] = delegate() {
            rr8(r.bc.b, r.af.f);
            return ubyte(8);
        };

        // RR C
        cbeTable[0x19] = delegate() {
            rr8(r.bc.c, r.af.f);
            return ubyte(8);
        };

        // RR D
        cbeTable[0x1a] = delegate() {
            rr8(r.de.d, r.af.f);
            return ubyte(8);
        };

        // RR E
        cbeTable[0x1b] = delegate() {
            rr8(r.de.e, r.af.f);
            return ubyte(8);
        };

        // RR H
        cbeTable[0x1c] = delegate() {
            rr8(r.hl.h, r.af.f);
            return ubyte(8);
        };

        // RR L
        cbeTable[0x1d] = delegate() {
            rr8(r.hl.l, r.af.f);
            return ubyte(8);
        };

        // RR (HL)
        cbeTable[0x1e] = delegate() {
            ubyte v = read8(r.hl.v);
            rr8(v, r.af.f);
            write8(r.hl.v, v);
            return ubyte(8);
        };

        // RR A
        cbeTable[0x1f] = delegate() {
            rr8(r.af.a, r.af.f);
            return ubyte(8);
        };

        // SLA B
        cbeTable[0x20] = delegate() {
            sla8(r.af.a, r.bc.b, r.af.f);
            return ubyte(8);
        };

        // SLA C
        cbeTable[0x21] = delegate() {
            sla8(r.af.a, r.bc.c, r.af.f);
            return ubyte(8);
        };

        // SLA D
        cbeTable[0x22] = delegate() {
            sla8(r.af.a, r.de.d, r.af.f);
            return ubyte(8);
        };

        // SLA E
        cbeTable[0x23] = delegate() {
            sla8(r.af.a, r.de.e, r.af.f);
            return ubyte(8);
        };

        // SLA H
        cbeTable[0x24] = delegate() {
            sla8(r.af.a, r.hl.h, r.af.f);
            return ubyte(8);
        };

        // SLA L
        cbeTable[0x25] = delegate() {
            sla8(r.af.a, r.hl.l, r.af.f);
            return ubyte(8);
        };

        // SLA (HL)
        cbeTable[0x26] = delegate() {
            ubyte v = read8(r.hl.v);
            sla8(r.af.a, v, r.af.f);
            write8(r.hl.v, v);
            return ubyte(16);
        };

        // SLA A
        cbeTable[0x27] = delegate() {
            sla8(r.af.a, r.af.a, r.af.f);
            return ubyte(8);
        };

        // SRA B
        cbeTable[0x28] = delegate() {
            sra8(r.af.a, r.bc.b, r.af.f);
            return ubyte(8);
        };

        // SRA C
        cbeTable[0x29] = delegate() {
            sra8(r.af.a, r.bc.c, r.af.f);
            return ubyte(8);
        };

        // SRA D
        cbeTable[0x2a] = delegate() {
            sra8(r.af.a, r.de.d, r.af.f);
            return ubyte(8);
        };

        // SRA E
        cbeTable[0x2b] = delegate() {
            sra8(r.af.a, r.de.e, r.af.f);
            return ubyte(8);
        };

        // SRA H
        cbeTable[0x2c] = delegate() {
            sra8(r.af.a, r.hl.h, r.af.f);
            return ubyte(8);
        };

        // SRA L
        cbeTable[0x2d] = delegate() {
            sra8(r.af.a, r.hl.l, r.af.f);
            return ubyte(8);
        };

        // SRA (HL)
        cbeTable[0x2e] = delegate() {
            ubyte v = read8(r.hl.v);
            sra8(r.af.a, v, r.af.f);
            write8(r.hl.v, v);
            return ubyte(16);
        };

        // SRA A
        cbeTable[0x2f] = delegate() {
            sra8(r.af.a, r.af.a, r.af.f);
            return ubyte(8);
        };

        // SWAP B
        cbeTable[0x30] = delegate() {
            swap8(r.bc.b, r.af.f);
            return ubyte(8);
        };

        // SWAP C
        cbeTable[0x31] = delegate() {
            swap8(r.bc.c, r.af.f);
            return ubyte(8);
        };

        // SWAP D
        cbeTable[0x32] = delegate() {
            swap8(r.de.d, r.af.f);
            return ubyte(8);
        };

        // SWAP E
        cbeTable[0x33] = delegate() {
            swap8(r.de.e, r.af.f);
            return ubyte(8);
        };

        // SWAP H
        cbeTable[0x34] = delegate() {
            swap8(r.hl.h, r.af.f);
            return ubyte(8);
        };

        // SWAP L
        cbeTable[0x35] = delegate() {
            swap8(r.hl.l, r.af.f);
            return ubyte(8);
        };

        // SWAP HL
        cbeTable[0x36] = delegate() {
            ubyte v = read8(r.hl.v);
            swap8(r.hl.l, r.af.f);
            write8(r.hl.v, v);
            return ubyte(8);
        };

        // SWAP A
        cbeTable[0x37] = delegate() {
            swap8(r.af.a, r.af.f);
            return ubyte(8);
        };

        // SRL B
        cbeTable[0x38] = delegate() {
            srl8(r.af.a, r.bc.b, r.af.f);
            return ubyte(8);
        };

        // SRL C
        cbeTable[0x39] = delegate() {
            srl8(r.af.a, r.bc.c, r.af.f);
            return ubyte(8);
        };

        // SRL D
        cbeTable[0x3a] = delegate() {
            srl8(r.af.a, r.de.d, r.af.f);
            return ubyte(8);
        };

        // SRL E
        cbeTable[0x3b] = delegate() {
            srl8(r.af.a, r.de.e, r.af.f);
            return ubyte(8);
        };

        // SRL H
        cbeTable[0x3c] = delegate() {
            srl8(r.af.a, r.hl.h, r.af.f);
            return ubyte(8);
        };

        // SRL L
        cbeTable[0x3d] = delegate() {
            srl8(r.af.a, r.hl.l, r.af.f);
            return ubyte(8);
        };

        // SRL (HL)
        cbeTable[0x3e] = delegate() {
            ubyte v = read8(r.hl.v);
            srl8(r.af.a, v, r.af.f);
            write8(r.hl.v, v);
            return ubyte(16);
        };

        // SRL A
        cbeTable[0x3f] = delegate() {
            srl8(r.af.a, r.af.a, r.af.f);
            return ubyte(8);
        };

        // BIT 0,B
        cbeTable[0x40] = delegate() {
            testBit8(r.bc.b, 0, r.af.f);
            return ubyte(8);
        };

        // BIT 0,C
        cbeTable[0x41] = delegate() {
            testBit8(r.bc.c, 0, r.af.f);
            return ubyte(8);
        };

        // BIT 0,D
        cbeTable[0x42] = delegate() {
            testBit8(r.de.d, 0, r.af.f);
            return ubyte(8);
        };

        // BIT 0,E
        cbeTable[0x43] = delegate() {
            testBit8(r.de.e, 0, r.af.f);
            return ubyte(8);
        };

        // BIT 0,H
        cbeTable[0x44] = delegate() {
            testBit8(r.hl.h, 0, r.af.f);
            return ubyte(8);
        };

        // BIT 0,L
        cbeTable[0x45] = delegate() {
            testBit8(r.hl.l, 0, r.af.f);
            return ubyte(8);
        };

        // BIT 0,(HL)
        cbeTable[0x46] = delegate() {
            ubyte v = read8(r.hl.v);
            testBit8(v, 0, r.af.f);
            return ubyte(8);
        };

        // BIT 0,A
        cbeTable[0x47] = delegate() {
            testBit8(r.af.a, 0, r.af.f);
            return ubyte(8);
        };

        // BIT 1,B
        cbeTable[0x48] = delegate() {
            testBit8(r.bc.b, 1, r.af.f);
            return ubyte(8);
        };

        // BIT 1,C
        cbeTable[0x49] = delegate() {
            testBit8(r.bc.c, 1, r.af.f);
            return ubyte(8);
        };

        // BIT 1,D
        cbeTable[0x4a] = delegate() {
            testBit8(r.de.d, 1, r.af.f);
            return ubyte(8);
        };

        // BIT 1,E
        cbeTable[0x4b] = delegate() {
            testBit8(r.de.e, 1, r.af.f);
            return ubyte(8);
        };

        // BIT 1,H
        cbeTable[0x4c] = delegate() {
            testBit8(r.hl.h, 1, r.af.f);
            return ubyte(8);
        };

        // BIT 1,L
        cbeTable[0x4d] = delegate() {
            testBit8(r.hl.l, 1, r.af.f);
            return ubyte(8);
        };

        // BIT 1,(HL)
        cbeTable[0x4e] = delegate() {
            ubyte v = read8(r.hl.v);
            testBit8(v, 1, r.af.f);
            return ubyte(16);
        };

        // BIT 1,A
        cbeTable[0x4f] = delegate() {
            testBit8(r.af.a, 1, r.af.f);
            return ubyte(8);
        };

        // BIT 2,B
        cbeTable[0x50] = delegate() {
            testBit8(r.bc.b, 2, r.af.f);
            return ubyte(8);
        };

        // BIT 2,C
        cbeTable[0x51] = delegate() {
            testBit8(r.bc.c, 2, r.af.f);
            return ubyte(8);
        };

        // BIT 2,D
        cbeTable[0x52] = delegate() {
            testBit8(r.de.d, 2, r.af.f);
            return ubyte(8);
        };

        // BIT 2,E
        cbeTable[0x53] = delegate() {
            testBit8(r.de.e, 2, r.af.f);
            return ubyte(8);
        };

        // BIT 2,H
        cbeTable[0x54] = delegate() {
            testBit8(r.hl.h, 2, r.af.f);
            return ubyte(8);
        };

        // BIT 2,L
        cbeTable[0x55] = delegate() {
            testBit8(r.hl.l, 2, r.af.f);
            return ubyte(8);
        };

        // BIT 2,(HL)
        cbeTable[0x56] = delegate() {
            ubyte v = read8(r.hl.v);
            testBit8(v, 2, r.af.f);
            return ubyte(8);
        };

        // BIT 2,A
        cbeTable[0x57] = delegate() {
            testBit8(r.af.a, 2, r.af.f);
            return ubyte(8);
        };

        // BIT 3,B
        cbeTable[0x58] = delegate() {
            testBit8(r.bc.b, 3, r.af.f);
            return ubyte(8);
        };

        // BIT 3,C
        cbeTable[0x59] = delegate() {
            testBit8(r.bc.c, 3, r.af.f);
            return ubyte(8);
        };

        // BIT 3,D
        cbeTable[0x5a] = delegate() {
            testBit8(r.de.d, 3, r.af.f);
            return ubyte(8);
        };

        // BIT 3,E
        cbeTable[0x5b] = delegate() {
            testBit8(r.de.e, 3, r.af.f);
            return ubyte(8);
        };

        // BIT 3,H
        cbeTable[0x5c] = delegate() {
            testBit8(r.hl.h, 3, r.af.f);
            return ubyte(8);
        };

        // BIT 3,L
        cbeTable[0x5d] = delegate() {
            testBit8(r.hl.l, 3, r.af.f);
            return ubyte(8);
        };

        // BIT 3,(HL)
        cbeTable[0x5e] = delegate() {
            ubyte v = read8(r.hl.v);
            testBit8(v, 3, r.af.f);
            return ubyte(16);
        };

        // BIT 3,A
        cbeTable[0x5f] = delegate() {
            testBit8(r.af.a, 3, r.af.f);
            return ubyte(8);
        };

        // BIT 4,B
        cbeTable[0x60] = delegate() {
            testBit8(r.bc.b, 4, r.af.f);
            return ubyte(8);
        };

        // BIT 4,C
        cbeTable[0x61] = delegate() {
            testBit8(r.bc.c, 4, r.af.f);
            return ubyte(8);
        };

        // BIT 4,D
        cbeTable[0x62] = delegate() {
            testBit8(r.de.d, 4, r.af.f);
            return ubyte(8);
        };

        // BIT 4,E
        cbeTable[0x63] = delegate() {
            testBit8(r.de.e, 4, r.af.f);
            return ubyte(8);
        };

        // BIT 4,H
        cbeTable[0x64] = delegate() {
            testBit8(r.hl.h, 4, r.af.f);
            return ubyte(8);
        };

        // BIT 4,L
        cbeTable[0x65] = delegate() {
            testBit8(r.hl.l, 4, r.af.f);
            return ubyte(8);
        };

        // BIT 4,(HL)
        cbeTable[0x66] = delegate() {
            ubyte v = read8(r.hl.v);
            testBit8(v, 4, r.af.f);
            return ubyte(8);
        };

        // BIT 4,A
        cbeTable[0x67] = delegate() {
            testBit8(r.af.a, 4, r.af.f);
            return ubyte(8);
        };

        // BIT 5,B
        cbeTable[0x68] = delegate() {
            testBit8(r.bc.b, 5, r.af.f);
            return ubyte(8);
        };

        // BIT 5,C
        cbeTable[0x69] = delegate() {
            testBit8(r.bc.c, 5, r.af.f);
            return ubyte(8);
        };

        // BIT 5,D
        cbeTable[0x6a] = delegate() {
            testBit8(r.de.d, 5, r.af.f);
            return ubyte(8);
        };

        // BIT 5,E
        cbeTable[0x6b] = delegate() {
            testBit8(r.de.e, 5, r.af.f);
            return ubyte(8);
        };

        // BIT 5,H
        cbeTable[0x6c] = delegate() {
            testBit8(r.hl.h, 5, r.af.f);
            return ubyte(8);
        };

        // BIT 5,L
        cbeTable[0x6d] = delegate() {
            testBit8(r.hl.l, 5, r.af.f);
            return ubyte(8);
        };

        // BIT 5,(HL)
        cbeTable[0x6e] = delegate() {
            ubyte v = read8(r.hl.v);
            testBit8(v, 5, r.af.f);
            return ubyte(16);
        };

        // BIT 5,A
        cbeTable[0x6f] = delegate() {
            testBit8(r.af.a, 5, r.af.f);
            return ubyte(8);
        };

        // BIT 6,B
        cbeTable[0x70] = delegate() {
            testBit8(r.bc.b, 6, r.af.f);
            return ubyte(8);
        };

        // BIT 6,C
        cbeTable[0x71] = delegate() {
            testBit8(r.bc.c, 6, r.af.f);
            return ubyte(8);
        };

        // BIT 6,D
        cbeTable[0x72] = delegate() {
            testBit8(r.de.d, 6, r.af.f);
            return ubyte(8);
        };

        // BIT 6,E
        cbeTable[0x73] = delegate() {
            testBit8(r.de.e, 6, r.af.f);
            return ubyte(8);
        };

        // BIT 6,H
        cbeTable[0x74] = delegate() {
            testBit8(r.hl.h, 6, r.af.f);
            return ubyte(8);
        };

        // BIT 6,L
        cbeTable[0x75] = delegate() {
            testBit8(r.hl.l, 6, r.af.f);
            return ubyte(8);
        };

        // BIT 6,(HL)
        cbeTable[0x76] = delegate() {
            ubyte v = read8(r.hl.v);
            testBit8(v, 6, r.af.f);
            return ubyte(8);
        };

        // BIT 6,A
        cbeTable[0x77] = delegate() {
            testBit8(r.af.a, 6, r.af.f);
            return ubyte(8);
        };

        // BIT 7,B
        cbeTable[0x78] = delegate() {
            testBit8(r.bc.b, 7, r.af.f);
            return ubyte(8);
        };

        // BIT 7,C
        cbeTable[0x79] = delegate() {
            testBit8(r.bc.c, 7, r.af.f);
            return ubyte(8);
        };

        // BIT 7,D
        cbeTable[0x7a] = delegate() {
            testBit8(r.de.d, 7, r.af.f);
            return ubyte(8);
        };

        // BIT 7,E
        cbeTable[0x7b] = delegate() {
            testBit8(r.de.e, 7, r.af.f);
            return ubyte(8);
        };

        // BIT 7,H
        cbeTable[0x7c] = delegate() {
            testBit8(r.hl.h, 7, r.af.f);
            return ubyte(8);
        };

        // BIT 7,L
        cbeTable[0x7d] = delegate() {
            testBit8(r.hl.l, 7, r.af.f);
            return ubyte(8);
        };

        // BIT 7,(HL)
        cbeTable[0x7e] = delegate() {
            ubyte v = read8(r.hl.v);
            testBit8(v, 7, r.af.f);
            return ubyte(16);
        };

        // BIT 7,A
        cbeTable[0x7f] = delegate() {
            testBit8(r.af.a, 7, r.af.f);
            return ubyte(8);
        };

        // RES 0,B
        cbeTable[0x80] = delegate() {
            resetBit8(r.bc.b, 0);
            return ubyte(8);
        };

        // RES 0,C
        cbeTable[0x81] = delegate() {
            resetBit8(r.bc.c, 0);
            return ubyte(8);
        };

        // RES 0,D
        cbeTable[0x82] = delegate() {
            resetBit8(r.de.d, 0);
            return ubyte(8);
        };

        // RES 0,E
        cbeTable[0x83] = delegate() {
            resetBit8(r.de.e, 0);
            return ubyte(8);
        };

        // RES 0,H
        cbeTable[0x84] = delegate() {
            resetBit8(r.hl.h, 0);
            return ubyte(8);
        };

        // RES 0,L
        cbeTable[0x85] = delegate() {
            resetBit8(r.hl.l, 0);
            return ubyte(8);
        };

        // RES 0,(HL)
        cbeTable[0x86] = delegate() {
            ubyte v = read8(r.hl.v);
            resetBit8(v, 0);
            return ubyte(8);
        };

        // RES 0,A
        cbeTable[0x87] = delegate() {
            resetBit8(r.af.a, 0);
            return ubyte(8);
        };

        // RES 1,B
        cbeTable[0x88] = delegate() {
            resetBit8(r.bc.b, 1);
            return ubyte(8);
        };

        // RES 1,C
        cbeTable[0x89] = delegate() {
            resetBit8(r.bc.c, 1);
            return ubyte(8);
        };

        // RES 1,D
        cbeTable[0x8a] = delegate() {
            resetBit8(r.de.d, 1);
            return ubyte(8);
        };

        // RES 1,E
        cbeTable[0x8b] = delegate() {
            resetBit8(r.de.e, 1);
            return ubyte(8);
        };

        // RES 1,H
        cbeTable[0x8c] = delegate() {
            resetBit8(r.hl.h, 1);
            return ubyte(8);
        };

        // RES 1,L
        cbeTable[0x8d] = delegate() {
            resetBit8(r.hl.l, 1);
            return ubyte(8);
        };

        // RES 1,(HL)
        cbeTable[0x8e] = delegate() {
            ubyte v = read8(r.hl.v);
            resetBit8(v, 1);
            return ubyte(16);
        };

        // RES 1,A
        cbeTable[0x8f] = delegate() {
            resetBit8(r.af.a, 1);
            return ubyte(8);
        };

        // RES 2,B
        cbeTable[0x90] = delegate() {
            resetBit8(r.bc.b, 2);
            return ubyte(8);
        };

        // RES 2,C
        cbeTable[0x91] = delegate() {
            resetBit8(r.bc.c, 2);
            return ubyte(8);
        };

        // RES 2,D
        cbeTable[0x92] = delegate() {
            resetBit8(r.de.d, 2);
            return ubyte(8);
        };

        // RES 2,E
        cbeTable[0x93] = delegate() {
            resetBit8(r.de.e, 2);
            return ubyte(8);
        };

        // RES 2,H
        cbeTable[0x94] = delegate() {
            resetBit8(r.hl.h, 2);
            return ubyte(8);
        };

        // RES 2,L
        cbeTable[0x95] = delegate() {
            resetBit8(r.hl.l, 2);
            return ubyte(8);
        };

        // RES 2,(HL)
        cbeTable[0x96] = delegate() {
            ubyte v = read8(r.hl.v);
            resetBit8(v, 2);
            return ubyte(8);
        };

        // RES 2,A
        cbeTable[0x97] = delegate() {
            resetBit8(r.af.a, 2);
            return ubyte(8);
        };

        // RES 3,B
        cbeTable[0x98] = delegate() {
            resetBit8(r.bc.b, 3);
            return ubyte(8);
        };

        // RES 3,C
        cbeTable[0x99] = delegate() {
            resetBit8(r.bc.c, 3);
            return ubyte(8);
        };

        // RES 3,D
        cbeTable[0x9a] = delegate() {
            resetBit8(r.de.d, 3);
            return ubyte(8);
        };

        // RES 3,E
        cbeTable[0x9b] = delegate() {
            resetBit8(r.de.e, 3);
            return ubyte(8);
        };

        // RES 3,H
        cbeTable[0x9c] = delegate() {
            resetBit8(r.hl.h, 3);
            return ubyte(8);
        };

        // RES 3,L
        cbeTable[0x9d] = delegate() {
            resetBit8(r.hl.l, 3);
            return ubyte(8);
        };

        // RES 3,(HL)
        cbeTable[0x9e] = delegate() {
            ubyte v = read8(r.hl.v);
            resetBit8(v, 3);
            return ubyte(16);
        };

        // RES 3,A
        cbeTable[0x9f] = delegate() {
            resetBit8(r.af.a, 3);
            return ubyte(8);
        };

        // RES 4,B
        cbeTable[0xa0] = delegate() {
            resetBit8(r.bc.b, 4);
            return ubyte(8);
        };

        // RES 4,C
        cbeTable[0xa1] = delegate() {
            resetBit8(r.bc.c, 4);
            return ubyte(8);
        };

        // RES 4,D
        cbeTable[0xa2] = delegate() {
            resetBit8(r.de.d, 4);
            return ubyte(8);
        };

        // RES 4,E
        cbeTable[0xa3] = delegate() {
            resetBit8(r.de.e, 4);
            return ubyte(8);
        };

        // RES 4,H
        cbeTable[0xa4] = delegate() {
            resetBit8(r.hl.h, 4);
            return ubyte(8);
        };

        // RES 4,L
        cbeTable[0xa5] = delegate() {
            resetBit8(r.hl.l, 4);
            return ubyte(8);
        };

        // RES 4,(HL)
        cbeTable[0xa6] = delegate() {
            ubyte v = read8(r.hl.v);
            resetBit8(v, 4);
            return ubyte(8);
        };

        // RES 4,A
        cbeTable[0xa7] = delegate() {
            resetBit8(r.af.a, 4);
            return ubyte(8);
        };

        // RES 5,B
        cbeTable[0xa8] = delegate() {
            resetBit8(r.bc.b, 5);
            return ubyte(8);
        };

        // RES 5,C
        cbeTable[0xa9] = delegate() {
            resetBit8(r.bc.c, 5);
            return ubyte(8);
        };

        // RES 5,D
        cbeTable[0xaa] = delegate() {
            resetBit8(r.de.d, 5);
            return ubyte(8);
        };

        // RES 5,E
        cbeTable[0xab] = delegate() {
            resetBit8(r.de.e, 5);
            return ubyte(8);
        };

        // RES 5,H
        cbeTable[0xac] = delegate() {
            resetBit8(r.hl.h, 5);
            return ubyte(8);
        };

        // RES 5,L
        cbeTable[0xad] = delegate() {
            resetBit8(r.hl.l, 5);
            return ubyte(8);
        };

        // RES 5,(HL)
        cbeTable[0xae] = delegate() {
            ubyte v = read8(r.hl.v);
            resetBit8(v, 5);
            return ubyte(16);
        };

        // RES 5,A
        cbeTable[0xaf] = delegate() {
            resetBit8(r.af.a, 5);
            return ubyte(8);
        };

        // RES 6,B
        cbeTable[0xb0] = delegate() {
            resetBit8(r.bc.b, 6);
            return ubyte(8);
        };

        // RES 6,C
        cbeTable[0xb1] = delegate() {
            resetBit8(r.bc.c, 6);
            return ubyte(8);
        };

        // RES 6,D
        cbeTable[0xb2] = delegate() {
            resetBit8(r.de.d, 6);
            return ubyte(8);
        };

        // RES 6,E
        cbeTable[0xb3] = delegate() {
            resetBit8(r.de.e, 6);
            return ubyte(8);
        };

        // RES 6,H
        cbeTable[0xb4] = delegate() {
            resetBit8(r.hl.h, 6);
            return ubyte(8);
        };

        // RES 6,L
        cbeTable[0xb5] = delegate() {
            resetBit8(r.hl.l, 6);
            return ubyte(8);
        };

        // RES 6,(HL)
        cbeTable[0xb6] = delegate() {
            ubyte v = read8(r.hl.v);
            resetBit8(v, 6);
            return ubyte(8);
        };

        // RES 6,A
        cbeTable[0xb7] = delegate() {
            resetBit8(r.af.a, 6);
            return ubyte(8);
        };

        // RES 7,B
        cbeTable[0xb8] = delegate() {
            resetBit8(r.bc.b, 7);
            return ubyte(8);
        };

        // RES 7,C
        cbeTable[0xb9] = delegate() {
            resetBit8(r.bc.c, 7);
            return ubyte(8);
        };

        // RES 7,D
        cbeTable[0xba] = delegate() {
            resetBit8(r.de.d, 7);
            return ubyte(8);
        };

        // RES 7,E
        cbeTable[0xbb] = delegate() {
            resetBit8(r.de.e, 7);
            return ubyte(8);
        };

        // RES 7,H
        cbeTable[0xbc] = delegate() {
            resetBit8(r.hl.h, 7);
            return ubyte(8);
        };

        // RES 7,L
        cbeTable[0xbd] = delegate() {
            resetBit8(r.hl.l, 7);
            return ubyte(8);
        };

        // RES 7,(HL)
        cbeTable[0xbe] = delegate() {
            ubyte v = read8(r.hl.v);
            resetBit8(v, 7);
            return ubyte(16);
        };

        // RES 7,A
        cbeTable[0xbf] = delegate() {
            resetBit8(r.af.a, 7);
            return ubyte(8);
        };

        // SET 0,B
        cbeTable[0xc0] = delegate() {
            setBit8(r.bc.b, 0);
            return ubyte(8);
        };

        // SET 0,C
        cbeTable[0xc1] = delegate() {
            setBit8(r.bc.c, 0);
            return ubyte(8);
        };

        // SET 0,D
        cbeTable[0xc2] = delegate() {
            setBit8(r.de.d, 0);
            return ubyte(8);
        };

        // SET 0,E
        cbeTable[0xc3] = delegate() {
            setBit8(r.de.e, 0);
            return ubyte(8);
        };

        // SET 0,H
        cbeTable[0xc4] = delegate() {
            setBit8(r.hl.h, 0);
            return ubyte(8);
        };

        // SET 0,L
        cbeTable[0xc5] = delegate() {
            setBit8(r.hl.l, 0);
            return ubyte(8);
        };

        // SET 0,(HL)
        cbeTable[0xc6] = delegate() {
            ubyte v = read8(r.hl.v);
            setBit8(v, 0);
            return ubyte(8);
        };

        // SET 0,A
        cbeTable[0xc7] = delegate() {
            setBit8(r.af.a, 0);
            return ubyte(8);
        };

        // SET 1,B
        cbeTable[0xc8] = delegate() {
            setBit8(r.bc.b, 1);
            return ubyte(8);
        };

        // SET 1,C
        cbeTable[0xc9] = delegate() {
            setBit8(r.bc.c, 1);
            return ubyte(8);
        };

        // SET 1,D
        cbeTable[0xca] = delegate() {
            setBit8(r.de.d, 1);
            return ubyte(8);
        };

        // SET 1,E
        cbeTable[0xcb] = delegate() {
            setBit8(r.de.e, 1);
            return ubyte(8);
        };

        // SET 1,H
        cbeTable[0xcc] = delegate() {
            setBit8(r.hl.h, 1);
            return ubyte(8);
        };

        // SET 1,L
        cbeTable[0xcd] = delegate() {
            setBit8(r.hl.l, 1);
            return ubyte(8);
        };

        // SET 1,(HL)
        cbeTable[0xce] = delegate() {
            ubyte v = read8(r.hl.v);
            setBit8(v, 1);
            return ubyte(16);
        };

        // SET 1,A
        cbeTable[0xcf] = delegate() {
            setBit8(r.af.a, 1);
            return ubyte(8);
        };

        // SET 2,B
        cbeTable[0xd0] = delegate() {
            setBit8(r.bc.b, 2);
            return ubyte(8);
        };

        // SET 2,C
        cbeTable[0xd1] = delegate() {
            setBit8(r.bc.c, 2);
            return ubyte(8);
        };

        // SET 2,D
        cbeTable[0xd2] = delegate() {
            setBit8(r.de.d, 2);
            return ubyte(8);
        };

        // SET 2,E
        cbeTable[0xd3] = delegate() {
            setBit8(r.de.e, 2);
            return ubyte(8);
        };

        // SET 2,H
        cbeTable[0xd4] = delegate() {
            setBit8(r.hl.h, 2);
            return ubyte(8);
        };

        // SET 2,L
        cbeTable[0xd5] = delegate() {
            setBit8(r.hl.l, 2);
            return ubyte(8);
        };

        // SET 2,(HL)
        cbeTable[0xd6] = delegate() {
            ubyte v = read8(r.hl.v);
            setBit8(v, 2);
            return ubyte(8);
        };

        // SET 2,A
        cbeTable[0xd7] = delegate() {
            setBit8(r.af.a, 2);
            return ubyte(8);
        };

        // SET 3,B
        cbeTable[0xd8] = delegate() {
            setBit8(r.bc.b, 3);
            return ubyte(8);
        };

        // SET 3,C
        cbeTable[0xd9] = delegate() {
            setBit8(r.bc.c, 3);
            return ubyte(8);
        };

        // SET 3,D
        cbeTable[0xda] = delegate() {
            setBit8(r.de.d, 3);
            return ubyte(8);
        };

        // SET 3,E
        cbeTable[0xdb] = delegate() {
            setBit8(r.de.e, 3);
            return ubyte(8);
        };

        // SET 3,H
        cbeTable[0xdc] = delegate() {
            setBit8(r.hl.h, 3);
            return ubyte(8);
        };

        // SET 3,L
        cbeTable[0xdd] = delegate() {
            setBit8(r.hl.l, 3);
            return ubyte(8);
        };

        // SET 3,(HL)
        cbeTable[0xde] = delegate() {
            ubyte v = read8(r.hl.v);
            setBit8(v, 3);
            return ubyte(16);
        };

        // SET 3,A
        cbeTable[0xdf] = delegate() {
            setBit8(r.af.a, 3);
            return ubyte(8);
        };

        // SET 4,B
        cbeTable[0xe0] = delegate() {
            setBit8(r.bc.b, 4);
            return ubyte(8);
        };

        // SET 4,C
        cbeTable[0xe1] = delegate() {
            setBit8(r.bc.c, 4);
            return ubyte(8);
        };

        // SET 4,D
        cbeTable[0xe2] = delegate() {
            setBit8(r.de.d, 4);
            return ubyte(8);
        };

        // SET 4,E
        cbeTable[0xe3] = delegate() {
            setBit8(r.de.e, 4);
            return ubyte(8);
        };

        // SET 4,H
        cbeTable[0xe4] = delegate() {
            setBit8(r.hl.h, 4);
            return ubyte(8);
        };

        // SET 4,L
        cbeTable[0xe5] = delegate() {
            setBit8(r.hl.l, 4);
            return ubyte(8);
        };

        // SET 4,(HL)
        cbeTable[0xe6] = delegate() {
            ubyte v = read8(r.hl.v);
            setBit8(v, 4);
            return ubyte(8);
        };

        // SET 4,A
        cbeTable[0xe7] = delegate() {
            setBit8(r.af.a, 4);
            return ubyte(8);
        };

        // SET 5,B
        cbeTable[0xe8] = delegate() {
            setBit8(r.bc.b, 5);
            return ubyte(8);
        };

        // SET 5,C
        cbeTable[0xe9] = delegate() {
            setBit8(r.bc.c, 5);
            return ubyte(8);
        };

        // SET 5,D
        cbeTable[0xea] = delegate() {
            setBit8(r.de.d, 5);
            return ubyte(8);
        };

        // SET 5,E
        cbeTable[0xeb] = delegate() {
            setBit8(r.de.e, 5);
            return ubyte(8);
        };

        // SET 5,H
        cbeTable[0xec] = delegate() {
            setBit8(r.hl.h, 5);
            return ubyte(8);
        };

        // SET 5,L
        cbeTable[0xed] = delegate() {
            setBit8(r.hl.l, 5);
            return ubyte(8);
        };

        // SET 5,(HL)
        cbeTable[0xee] = delegate() {
            ubyte v = read8(r.hl.v);
            setBit8(v, 5);
            return ubyte(16);
        };

        // SET 5,A
        cbeTable[0xef] = delegate() {
            setBit8(r.af.a, 5);
            return ubyte(8);
        };

        // SET 6,B
        cbeTable[0xf0] = delegate() {
            setBit8(r.bc.b, 6);
            return ubyte(8);
        };

        // SET 6,C
        cbeTable[0xf1] = delegate() {
            setBit8(r.bc.c, 6);
            return ubyte(8);
        };

        // SET 6,D
        cbeTable[0xf2] = delegate() {
            setBit8(r.de.d, 6);
            return ubyte(8);
        };

        // SET 6,E
        cbeTable[0xf3] = delegate() {
            setBit8(r.de.e, 6);
            return ubyte(8);
        };

        // SET 6,H
        cbeTable[0xf4] = delegate() {
            setBit8(r.hl.h, 6);
            return ubyte(8);
        };

        // SET 6,L
        cbeTable[0xf5] = delegate() {
            setBit8(r.hl.l, 6);
            return ubyte(8);
        };

        // SET 6,(HL)
        cbeTable[0xf6] = delegate() {
            ubyte v = read8(r.hl.v);
            setBit8(v, 6);
            return ubyte(8);
        };

        // SET 6,A
        cbeTable[0xf7] = delegate() {
            setBit8(r.af.a, 6);
            return ubyte(8);
        };

        // SET 7,B
        cbeTable[0xf8] = delegate() {
            setBit8(r.bc.b, 7);
            return ubyte(8);
        };

        // SET 7,C
        cbeTable[0xf9] = delegate() {
            setBit8(r.bc.c, 7);
            return ubyte(8);
        };

        // SET 7,D
        cbeTable[0xfa] = delegate() {
            setBit8(r.de.d, 7);
            return ubyte(8);
        };

        // SET 7,E
        cbeTable[0xfb] = delegate() {
            setBit8(r.de.e, 7);
            return ubyte(8);
        };

        // SET 7,H
        cbeTable[0xfc] = delegate() {
            setBit8(r.hl.h, 7);
            return ubyte(8);
        };

        // SET 7,L
        cbeTable[0xfd] = delegate() {
            setBit8(r.hl.l, 7);
            return ubyte(8);
        };

        // SET 7,(HL)
        cbeTable[0xfe] = delegate() {
            ubyte v = read8(r.hl.v);
            setBit8(v, 7);
            return ubyte(16);
        };

        // SET 7,A
        cbeTable[0xff] = delegate() {
            setBit8(r.af.a, 7);
            return ubyte(8);
        };
    }

    // test rlca
    unittest {
        Cpu cpu = new Cpu();
        cpu.r.af.a = 0x80;
        cpu.isaTable[0x07](); // rlca
        assert(cpu.r.af.a == 0x01);
        assert(cpu.r.af.f == FLAG_CARRY);
    }

    // test rrca
    unittest {
        Cpu cpu = new Cpu();
        cpu.r.af.a = 0x01;
        cpu.isaTable[0x0f](); // rrca
        assert(cpu.r.af.a == 0x80);
        assert(cpu.r.af.f == FLAG_CARRY);
    }

    // test rla
    unittest {
        Cpu cpu = new Cpu();
        cpu.r.af.a = 0x80;
        cpu.isaTable[0x17](); // rla
        assert(cpu.r.af.a == 0);
        assert(cpu.r.af.f == FLAG_CARRY);
    }

    // test rra
    unittest
    {
        Cpu cpu = new Cpu();
        cpu.r.af.a = 0x01;
        cpu.isaTable[0x1f](); // rra
        assert(cpu.r.af.a == 0);
        assert(cpu.r.af.f == FLAG_CARRY);
    }

    // call routine
    private void call(ushort addr) {
        push(r.pc);
        ubyte lsb = read8(addr++);
        ubyte msb = read8(addr);
        addr = (msb << 8) + lsb;
        jp(addr);
    }

    // ret routine
    private void ret() {
        r.sp -= 2;
        jp(read16(r.sp));
    }

    // rst routine
    private void rst(ubyte routine) {
        push(r.pc);
        jp(routine);
    }

    // pop routine
    private void pop(ref ushort reg) {
        reg = read16(r.sp);
        r.sp += 2;
    }

    // push routine
    private void push(ushort reg) {
        r.sp -= 2;
        write16(r.sp, reg);
    }

    // jump relative
    private void jr(byte offset)
    {
        r.pc += offset;
    }

    // jump absolute
    private void jp(ushort address)
    {
        r.pc = address;
    }

    // auxiliary functions

    // set mask if set else resets
    private static pure void setFlag(ref ubyte flags, ubyte mask, ubyte set)
    {
        if (set)
        {
            flags |= mask;
        }
        else // reset
        {
            flags &= ~mask;
        }
    }

    unittest
    {
        ubyte flags = 0x80;
        setFlag(flags, 0x04, true);
        assert(flags == 0x84);

        flags = 0xff;
        setFlag(flags, 0x88, false);
        assert(flags == 0x77);
    }

    // 8 bits arithmetics

    /// add for 8 bits registers
    private static pure void add8(ref ubyte acc, ubyte reg, ref ubyte f) {
        bool halfCarry = ((acc & 0xf) + (reg & 0xf)) > 0xf;  // carry from bit 3
        bool fullCarry = (ushort(acc) + ushort(reg)) > 0xff; // carry from bit 7
        acc += reg;

        setFlag(f, FLAG_NEG,   false);
        setFlag(f, FLAG_ZERO,  acc == 0);
        setFlag(f, FLAG_HALF,  halfCarry);
        setFlag(f, FLAG_CARRY, fullCarry);
    }

    unittest
    {
        // test zero flag and neg reset
        ubyte acc = 0;
        ubyte reg = 0;
        ubyte flags = FLAG_NEG; // must be reset
        add8(acc, reg, flags);
        assert(acc == 0);
        assert(flags == FLAG_ZERO);

        // test half carry set by nibble overflow
        acc = 1; reg = 127; flags = 0;
        add8(acc, reg, flags);
        assert(acc == 128);
        assert(flags == FLAG_HALF);

        // test zero flag and carry set by overflow
        acc = 128; reg = 128; flags = 0;
        add8(acc, reg, flags);
        assert(acc == 0);
        assert(flags == (FLAG_ZERO | FLAG_CARRY));
    }

    // add with carry for 8 bits registers
    private static pure void adc8(ref ubyte acc, ref ubyte reg, ref ubyte f)
    {
        ubyte carry = (f & FLAG_CARRY) ? 1 : 0;

        bool halfCarry = ((acc & 0xf) + (reg & 0xf) + carry) > 0xf;  // carry from bit 3
        bool fullCarry = (ushort(acc) + ushort(reg) + carry) > 0xff; // carry from bit 7
        acc += reg + carry;

        setFlag(f, FLAG_NEG,   false);
        setFlag(f, FLAG_ZERO,  acc == 0);
        setFlag(f, FLAG_HALF,  halfCarry);
        setFlag(f, FLAG_CARRY, fullCarry);
    }

    unittest
    {
        // test carry increment
        ubyte acc = 0;
        ubyte reg = 0;
        ubyte flags = (FLAG_NEG | FLAG_CARRY); // must be reset
        adc8(acc, reg, flags);
        assert(acc == 1);
        assert(flags == 0);

        // test half carry and carry increment
        acc = 1; reg = 127; flags = FLAG_CARRY;
        adc8(acc, reg, flags);
        assert(acc == 129);
        assert(flags == (FLAG_HALF));

        // test half carry set
        acc = 1; reg = 127; flags = 0;
        adc8(acc, reg, flags);
        assert(acc == 128);
        assert(flags == (FLAG_HALF));

        // test zero flag and carry set by overflow
        acc = 128; reg = 128; flags = 0;
        adc8(acc, reg, flags);
        assert(acc == 0);
        assert(flags == (FLAG_ZERO | FLAG_CARRY));
    }

    // sub for 8 bits registers
    private static pure void sub8(ref ubyte acc, ubyte reg, ref ubyte f)
    {
        bool halfCarry = true; // no borrow from bit 4
        bool fullCarry = true; // no borrow

        for (int i = 0; i < 8; i++)
        {
            ubyte mask = ubyte((1 << i) & 0xff);
            bool borrow = (acc & mask) < (reg & mask);

            if (i == 3 && (borrow || !fullCarry)) {
                halfCarry = false;
            }

            if (borrow)
            {
                fullCarry = false;
            }
        }

        // sub operation
        acc -= reg;

        setFlag(f, FLAG_NEG,   true);
        setFlag(f, FLAG_ZERO,  acc == 0);
        setFlag(f, FLAG_HALF,  halfCarry);
        setFlag(f, FLAG_CARRY, fullCarry);
    }

    unittest
    {
        // test set all flags
        ubyte acc = 0;
        ubyte reg = 0;
        ubyte flags = 0;
        sub8(acc, reg, flags);
        assert(acc == 0);
        assert(flags == (FLAG_ZERO | FLAG_NEG | FLAG_HALF | FLAG_CARRY));

        // test borrow
        acc = 0x10; reg = 0x01; flags = 0;
        sub8(acc, reg, flags);
        assert(acc == 0x0f);
        assert(flags == FLAG_NEG);

        acc = 0xf0; reg = 0x80; flags = 0;
        sub8(acc, reg, flags);
        assert(acc == 0x70);
        assert(flags == (FLAG_NEG | FLAG_CARRY | FLAG_HALF));
    }

    // sub carry for 8 bits registers
    private static pure void sbc8(ref ubyte acc, ubyte reg, ref ubyte f)
    {
        reg += (f & FLAG_CARRY) ? 1 : 0;
        sub8(acc, reg, f);
    }

    unittest
    {
        // test set all flags
        ubyte acc = 0;
        ubyte reg = 0;
        ubyte flags = 0;
        sbc8(acc, reg, flags);
        assert(acc == 0);
        assert(flags == (FLAG_ZERO | FLAG_NEG | FLAG_HALF | FLAG_CARRY));

        // test carry
        acc = 0x10; reg = 0x01; flags = FLAG_CARRY;
        sbc8(acc, reg, flags);
        assert(acc == 0x0e);
        assert(flags == (FLAG_NEG));

        acc = 0xf0; reg = 0x80; flags = FLAG_CARRY;
        sbc8(acc, reg, flags);
        assert(acc == 0x6f);
        assert(flags == (FLAG_NEG));
    }

    // and for 8 bit registers
    private static pure void and8(ref ubyte acc, ubyte reg, ref ubyte f)
    {
        acc &= reg;

        setFlag(f, FLAG_HALF, true);
        setFlag(f, FLAG_NEG | FLAG_CARRY, false);
        setFlag(f, FLAG_ZERO, acc == 0);
    }

    unittest
    {
        ubyte acc = 0;
        ubyte reg = 0;
        ubyte flags = 0;
        and8(acc, reg, flags);
        assert(acc == 0);
        assert(flags == (FLAG_ZERO | FLAG_HALF));

        acc = 0xfe; reg = 0xef; flags = FLAG_NEG;
        and8(acc, reg, flags);
        assert(acc == 0xee);
        assert(flags == (FLAG_HALF));
    }

    // or for 8 bits registers
    private static pure void or8(ref ubyte acc, ubyte reg, ref ubyte f)
    {
        acc |= reg;

        setFlag(f, FLAG_NEG | FLAG_HALF | FLAG_CARRY, false);
        setFlag(f, FLAG_ZERO, acc == 0);
    }

    unittest
    {
        // test zero flag
        ubyte acc = 0;
        ubyte reg = 0;
        ubyte flags = 0;
        or8(acc, reg, flags);
        assert(acc == 0);
        assert(flags == FLAG_ZERO);

        // test reset flags and or
        acc = 0xf0; reg = 0x0f; flags = (FLAG_NEG | FLAG_HALF | FLAG_CARRY);
        or8(acc, reg, flags);
        assert(acc == 0xff);
        assert(flags == 0);
    }

    // or for 8 bits registers
    private static pure void xor8(ref ubyte acc, ubyte reg, ref ubyte f)
    {
        acc ^= reg;

        setFlag(f, FLAG_NEG | FLAG_HALF | FLAG_CARRY, false);
        setFlag(f, FLAG_ZERO, acc == 0);
    }

    unittest
    {
        // test zero flag
        ubyte acc = 0;
        ubyte reg = 0;
        ubyte flags = 0;
        xor8(acc, reg, flags);
        assert(acc == 0);
        assert(flags == FLAG_ZERO);

        // test reset flags and xor
        acc = 0xf1; reg = 0x0f; flags = (FLAG_NEG | FLAG_HALF | FLAG_CARRY);
        xor8(acc, reg, flags);
        assert(acc == 0xfe);
        assert(flags == 0);
    }

    // cp for 8 bits registers
    private static pure void cp8(ubyte acc, ubyte reg, ref ubyte f)
    {
        bool less = acc < reg;

        // just a sub, but result is ignored that is why acc is not a ref
        sub8(acc, reg, f);

        // except for this modified behavior
        if (less)
        {
            setFlag(f, FLAG_CARRY, true);
        }
    }

    unittest
    {
        ubyte acc = 0;
        ubyte reg = 0;
        ubyte flags = 0;
        cp8(acc, reg, flags);
        assert(flags == (FLAG_ZERO | FLAG_NEG | FLAG_HALF | FLAG_CARRY)); // equals and less than

        acc = 0xf; reg = 0xf; flags = 0;
        cp8(acc, reg, flags);
        assert(acc == 0xf); // shouldn't change
        assert(flags == (FLAG_ZERO | FLAG_NEG | FLAG_HALF | FLAG_CARRY)); // equals and less than

        acc = 0x1; reg = 0xf; flags = 0;
        cp8(acc, reg, flags);
        assert(acc == 0x1);
        assert(flags == (FLAG_NEG | FLAG_CARRY)); // not equals and less than

        acc = 0x80; reg = 0x40; flags = 0;
        cp8(acc, reg, flags);
        assert(acc == 0x80);
        assert(flags == (FLAG_NEG | FLAG_HALF)); // not equals and greater than

        acc = 0x8; reg = 0x4; flags = 0;
        cp8(acc, reg, flags);
        assert(acc == 0x8);
        assert(flags == (FLAG_NEG)); // not equals and greater than
    }

    private static pure void inc8(ref ubyte r, ref ubyte f)
    {
        bool halfCarry = (r & 0xf) == 0xf;
        r += 1;

        setFlag(f, FLAG_ZERO,  r == 0);
        setFlag(f, FLAG_NEG,   false);
        setFlag(f, FLAG_HALF,  halfCarry);
    }

    unittest
    {
        ubyte acc = 0;
        ubyte flags = (FLAG_NEG | FLAG_CARRY); // (reset, keep)
        inc8(acc, flags);
        assert(acc == 1);
        assert(flags == FLAG_CARRY);

        acc = 0xff; flags = 0;
        inc8(acc, flags);
        assert(acc == 0);
        assert(flags == (FLAG_ZERO | FLAG_HALF));
    }

    private static pure void dec8(ref ubyte r, ref ubyte f)
    {
        bool halfCarry = (r & 0xf) == 0;
        r -= 1;

        setFlag(f, FLAG_ZERO, r == 0);
        setFlag(f, FLAG_NEG, true);
        setFlag(f, FLAG_HALF, halfCarry);
    }

    unittest
    {
        ubyte acc = 0;
        ubyte flags = FLAG_CARRY; // keep
        dec8(acc, flags);
        assert(acc == 255);
        assert(flags == (FLAG_NEG | FLAG_HALF | FLAG_CARRY));

        acc = 1; flags = 0;
        dec8(acc, flags);
        assert(acc == 0);
        assert(flags == (FLAG_ZERO | FLAG_NEG));
    }

    // 16 bits arithmetics

    // add for 16 bits registers
    private static pure void add16(ref ushort acc, ushort reg, ref ubyte f)
    {
        bool halfCarry = ((acc & 0xfff) + (reg & 0xfff)) > 0xfff;  // carry from bit 11
        bool fullCarry = (uint(acc) + uint(reg)) > 0xffff;         // carry from bit 15

        acc += reg;

        setFlag(f, FLAG_NEG,   false);
        setFlag(f, FLAG_HALF,  halfCarry);
        setFlag(f, FLAG_CARRY, fullCarry);
    }

    unittest
    {
        // test no flags set
        ushort acc = 0;
        ushort reg = 0;
        ubyte flags = 0;
        add16(acc, reg, flags);
        assert(acc == 0);
        assert(flags == 0);

        // test keep flag zero
        flags = FLAG_ZERO;
        add16(acc, reg, flags);
        assert(flags == FLAG_ZERO);

        acc = 0xfff; reg = 0x001; flags = 0;
        add16(acc, reg, flags);
        assert(flags == FLAG_HALF);

        acc = 0xffff; reg = 0x001; flags = 0;
        add16(acc, reg, flags);
        assert(flags == (FLAG_CARRY | FLAG_HALF));
    }

    // inc for 16 bits registers
    private static pure void inc16(ref ushort r)
    {
        r += 1;
        // No flag effects
    }

    unittest
    {
        ushort reg = 0;
        inc16(reg);
        assert(reg == 1);
    }

    // dec for 16 bits registers
    private static pure void dec16(ref ushort r)
    {
        r -= 1;
        // No flag effects
    }

    unittest
    {
        ushort reg = 1;
        dec16(reg);
        assert(reg == 0);
    }

    // Misc operations

    private static pure void swap8(ref ubyte r, ref ubyte f)
    {
        r = ((r & 0x0f) << 4) | ((r & 0xf0) >> 4);

        setFlag(f, FLAG_ZERO, r == 0);
        setFlag(f, FLAG_NEG | FLAG_HALF | FLAG_CARRY, false);
    }

    unittest
    {
        ubyte reg = 0xab;
        ubyte flags = 0;
        swap8(reg, flags);
        assert(reg == 0xba);
        assert(flags == 0);

        reg = 0; flags = 0;
        swap8(reg, flags);
        assert(reg == 0);
        assert(flags == FLAG_ZERO);
    }

    private static pure void daa8(ref ubyte r, ref ubyte f)
    {
        bool carry = (f & FLAG_CARRY) != 0;
        bool half  = (f & FLAG_HALF) != 0;
        bool neg   = (f & FLAG_NEG) != 0;

        bool setCarry = false;

        ubyte hn = (r >> 4) & 0xf; // higher nibble
        ubyte ln = r & 0xf;        // lower nibble

        if (!neg) // additive operation
        {
            /*
            --------------------------------------------------------------------------------
            |           | C Flag  | HEX value in | H Flag | HEX value in | Number  | C flag|
            | Operation | Before  | upper digit  | Before | lower digit  | added   | After |
            |           | DAA     | (bit 7-4)    | DAA    | (bit 3-0)    | to byte | DAA   |
            |------------------------------------------------------------------------------|
            |           |    0    |     0-9      |   0    |     0-9      |   00    |   0   | row 1
            |   ADD     |    0    |     0-8      |   0    |     A-F      |   06    |   0   | row 2
            |           |    0    |     0-9      |   1    |     0-3      |   06    |   0   | row 3
            |   ADC     |    0    |     A-F      |   0    |     0-9      |   60    |   1   | row 4
            |           |    0    |     9-F      |   0    |     A-F      |   66    |   1   | row 5
            |   INC     |    0    |     A-F      |   1    |     0-3      |   66    |   1   | row 6
            |           |    1    |     0-2      |   0    |     0-9      |   60    |   1   | row 7
            |           |    1    |     0-2      |   0    |     A-F      |   66    |   1   | row 8
            |           |    1    |     0-3      |   1    |     0-3      |   66    |   1   | row 9
            |------------------------------------------------------------------------------|
            */

            if (!carry && hn <= 9 && !half && ln <= 9) // row 1
            {
                // bcd value, no need to adjust
            }
            else if (!carry && hn < 9 && !half && ln > 9) // row 2
            {
                r += 0x06;
            }
            else if (!carry && hn <= 9 && half && ln <= 3) // row 3
            {
                r += 0x06;
            }
            else if (!carry && hn > 9 && !half && ln <= 9) // row 4
            {
                r += 0x60;
                setCarry = true;
            }
            else if (!carry && hn >= 9 && !half && ln > 9) // row 5
            {
                r += 0x66;
                setCarry = true;
            }
            else if (!carry && hn >= 9 && half && ln <= 3) // row 6
            {
                r += 0x66;
                setCarry = true;
            }
            else if (carry && hn <= 2 && !half && ln <= 9) // row 7
            {
                r += 0x60;
                setCarry = true;
            }
            else if (carry && hn <= 2 && !half && ln > 9) // row 8
            {
                r += 0x66;
                setCarry = true;
            }
            else if (carry && hn <= 3 && half && ln <= 3) // row 9
            {
                r += 0x66;
                setCarry = true;
            }
            else
            {
                // ???
            }
        }
        else // subtractive operations
        {
            /*
            --------------------------------------------------------------------------------
            |           | C Flag  | HEX value in | H Flag | HEX value in | Number  | C flag|
            | Operation | Before  | upper digit  | Before | lower digit  | added   | After |
            |           | DAA     | (bit 7-4)    | DAA    | (bit 3-0)    | to byte | DAA   |
            |------------------------------------------------------------------------------|
            |   SUB     |    0    |     0-9      |   0    |     0-9      |   00    |   0   | row 1
            |   SBC     |    0    |     0-8      |   1    |     6-F      |   FA    |   0   | row 2
            |   DEC     |    1    |     7-F      |   0    |     0-9      |   A0    |   1   | row 3
            |   NEG     |    1    |     6-F      |   1    |     6-F      |   9A    |   1   | row 4
            |------------------------------------------------------------------------------|
            */

            if (!carry && hn <= 9 && !half && ln <= 9) // row 1
            {
                // bcd value, no need to adjust
            }
            else if (!carry && hn <= 8 && half && ln >= 6) // row 2
            {
                r += 0xfa;
            }
            else if (carry && hn >= 7 && !half && ln <= 9) // row 3
            {
                r += 0xa0;
                setCarry = true;
            }
            else if (carry && hn >= 6 && half && ln >= 6) // row 4
            {
                r += 0x9a;
                setCarry = true;
            }
            else
            {
                // ???
            }
        }

        setFlag(f, FLAG_ZERO,  r == 0);
        setFlag(f, FLAG_HALF,  false);
        setFlag(f, FLAG_CARRY, setCarry);
    }

    unittest
    {
        ubyte a = 0x79;
        ubyte b = 0x35;
        ubyte f = 0;
        add8(a, b, f);
        daa8(a, f);
        assert(a == 0x14);
        assert(f == (FLAG_CARRY));
    }

    // complement of 8 bit register
    private static pure void cpl8(ref ubyte r, ref ubyte f)
    {
        r = ~r;
        setFlag(f, FLAG_NEG | FLAG_HALF, true);
    }

    unittest
    {
        ubyte reg = 0x00;
        ubyte flags = FLAG_ZERO | FLAG_CARRY;
        cpl8(reg, flags);
        assert(reg == 0xff);
        assert(flags == (FLAG_ZERO | FLAG_NEG | FLAG_HALF | FLAG_CARRY ));
    }

    // complement carry flag
    private static pure void ccf(ref ubyte f)
    {
        setFlag(f, FLAG_NEG | FLAG_HALF, false);
        setFlag(f, FLAG_CARRY, (f & FLAG_CARRY) == 0);
    }

    unittest
    {
        // test reset carry
        ubyte f = FLAG_CARRY;
        ccf(f);
        assert(f == 0);

        // test set carry and keep zero
        f = FLAG_ZERO | FLAG_NEG | FLAG_HALF;
        ccf(f);
        assert(f == (FLAG_ZERO | FLAG_CARRY));
    }

    // set carry flag
    private static pure void scf(ref ubyte f)
    {
        setFlag(f, FLAG_NEG | FLAG_HALF, false);
        setFlag(f, FLAG_CARRY, true);
    }

    unittest
    {
        // test set carry
        ubyte f = 0;
        scf(f);
        assert(f == FLAG_CARRY);

        // test keep zero, reset neg and half, set carry
        f = FLAG_ZERO | FLAG_NEG | FLAG_HALF | FLAG_CARRY;
        scf(f);
        assert(f == (FLAG_ZERO | FLAG_CARRY));
    }

    // rotate left, old 7th bit on carry
    private static pure void rlc8(ref ubyte r, ref ubyte f)
    {
        bool carry = (r & 0x80) != 0;
        r = rol(r , 1);

        setFlag(f, FLAG_ZERO, r == 0); // must be reset on RLCA, use as is in CB ext.
        setFlag(f, FLAG_NEG | FLAG_HALF, false);
        setFlag(f, FLAG_CARRY, carry);
    }

    unittest
    {
        ubyte acc = 0x80;
        ubyte flags  = 0;
        rlc8(acc, flags);
        assert(acc == 1);
        assert(flags == FLAG_CARRY);
    }

    // rotate left through carry
    private static pure void rl8(ref ubyte r, ref ubyte f)
    {
        bool carry = (r & 0x80) != 0;
        r <<= 1;

        // add carry to register
        if ((f & FLAG_CARRY) != 0)
        {
            r += 1;
        }

        setFlag(f, FLAG_ZERO, r == 0); // must be reset on RLA, use as is in CB ext.
        setFlag(f, FLAG_NEG | FLAG_HALF, false);
        setFlag(f, FLAG_CARRY, carry);
    }

    unittest
    {
        ubyte acc = 0x80;
        ubyte flags  = 0;
        rl8(acc, flags);
        assert(acc == 0);
        assert(flags == (FLAG_CARRY | FLAG_ZERO));
    }

    // rotate right, old bit 0 on carry
    private static pure void rrc8(ref ubyte r, ref ubyte f)
    {
        bool carry = (r & 0x01) != 0;
        r = ror(r , 1);

        setFlag(f, FLAG_ZERO, r == 0); // must be reset on RLCA, use as is in CB ext.
        setFlag(f, FLAG_NEG | FLAG_HALF, false);
        setFlag(f, FLAG_CARRY, carry);
    }

    unittest
    {
        ubyte acc = 0x01;
        ubyte flags  = 0;
        rrc8(acc, flags);
        assert(acc == 0x80);
        assert(flags == FLAG_CARRY);
    }

    // rotate right through carry
    private static pure void rr8(ref ubyte r, ref ubyte f)
    {
        bool carry = (r & 0x01) != 0;
        r >>= 1;

        // add carry to register
        if ((f & FLAG_CARRY) != 0)
        {
            r += 0x80;
        }

        setFlag(f, FLAG_ZERO, r == 0); // must be reset on RLCA, use as is in CB ext.
        setFlag(f, FLAG_NEG | FLAG_HALF, false);
        setFlag(f, FLAG_CARRY, carry);
    }

    unittest
    {
        ubyte acc = 0x01;
        ubyte flags  = 0;
        rr8(acc, flags);
        assert(acc == 0);
        assert(flags == (FLAG_CARRY | FLAG_ZERO));
    }

    // shift n left into carry
    private static pure void sla8(ref ubyte acc, ref ubyte reg, ref ubyte f)
    {
        bool carry = (acc & 0x80) != 0;
        acc <<= reg;

        setFlag(f, FLAG_ZERO, acc == 0);
        setFlag(f, FLAG_NEG | FLAG_HALF, false);
        setFlag(f, FLAG_CARRY, carry);
    }

    unittest
    {
        ubyte acc = 0x8F;
        ubyte reg = 4;
        ubyte flags  = 0;
        sla8(acc, reg, flags);
        assert(acc == 0xf0);
        assert(flags == FLAG_CARRY);
    }

    // shift n right into carry, msb don't change
    private static pure void sra8(ref ubyte acc, ubyte reg, ref ubyte f)
    {
        bool carry = (acc & 0x01) != 0;
        acc = (acc & 0x80) | (acc >> reg);

        setFlag(f, FLAG_ZERO, acc == 0);
        setFlag(f, FLAG_NEG | FLAG_HALF, false);
        setFlag(f, FLAG_CARRY, carry);
    }

    unittest
    {
        ubyte acc = 0x81;
        ubyte reg = 4;
        ubyte flags  = 0;
        sra8(acc, reg, flags);
        assert(acc == 0x88);
        assert(flags == FLAG_CARRY);
    }

    // shift n right into carry, msb set to 0
    private static pure void srl8(ref ubyte acc, ubyte reg, ref ubyte f)
    {
        bool carry = (acc & 0x01) != 0;
        acc = (acc >> reg) & 0x7f;

        setFlag(f, FLAG_ZERO, acc == 0);
        setFlag(f, FLAG_NEG | FLAG_HALF, false);
        setFlag(f, FLAG_CARRY, carry);
    }

    unittest
    {
        ubyte acc = 0x81;
        ubyte reg = 4;
        ubyte flags  = 0;
        srl8(acc, reg, flags);
        assert(acc == 0x08);
        assert(flags == FLAG_CARRY);
    }

    // test bit of register
    private static pure void testBit8(ubyte r, ubyte i, ref ubyte f)
    {
        ubyte mask = (1 << i) & 0xff;
        bool isSet = (r & mask) != 0;

        setFlag(f, FLAG_ZERO, !isSet); // Set if bit b of register r is 0
        setFlag(f, FLAG_NEG, false);
        setFlag(f, FLAG_HALF, true);
    }

    unittest
    {
        ubyte r = 0x80;
        ubyte f = 0;
        testBit8(r, 0, f);
        assert(f == (FLAG_ZERO | FLAG_HALF));

        f = 0;
        testBit8(r, 7, f);
        assert(f == FLAG_HALF);
    }

    // set a bit
    private static pure void setBit8(ref ubyte r, ubyte i)
    {
        r |= (1 << i) & 0xff;
    }

    unittest
    {
        ubyte r = 0x0;
        setBit8(r, 1);
        setBit8(r, 3);
        setBit8(r, 5);
        setBit8(r, 7);
        assert(r == 0b10101010);
    }

    // reset bit
    private static pure void resetBit8(ref ubyte r, ubyte i)
    {
        r &= ~((1 << i) & 0xff);
    }

    unittest
    {
        ubyte r = 0xff;
        resetBit8(r, 1);
        resetBit8(r, 3);
        resetBit8(r, 5);
        resetBit8(r, 7);
        assert(r == 0b01010101);
    }

}
