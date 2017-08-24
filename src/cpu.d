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

    Memory memory;

    // flags
    private static immutable ubyte FZ = 0x80; // zero flag
    private static immutable ubyte FN = 0x40; // add-sub flag (bcd)
    private static immutable ubyte FH = 0x20; // half carry flag (bcd)
    private static immutable ubyte FC = 0x10; // carry flag


    // instruction set architecture
    private ubyte delegate()[256] isaTable;

    this()
    {
        clear();
        fillIsa();

        memory = new NoMemory();
    }

    ubyte step()
    {
        // fetch
        ubyte opcode = memory.read8(r.pc++);

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
        r.hl.v = 0;
        r.sp = 0;
        r.pc = 0;
    }

    // Helpers

    void fillIsa()
    {
        // TODO: Populate ISA Table

        // NOP
        isaTable[0x00] = delegate() {
            return ubyte(4);
        };

        // LD BC,d16
        isaTable[0x01] = delegate() {
            r.bc.v = memory.read16(r.pc);
            r.pc += 2;
            return ubyte(12);
        };

        // LD (BC),A
        isaTable[0x02] = delegate() {
            memory.write8(r.bc.v, r.af.a);
            return ubyte(8);
        };

        // INC BC
        isaTable[0x03] = delegate() {
            inc16(r.bc.v, r.af.f);
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
            r.bc.b = memory.read8(r.pc);
            r.pc += 1;
            return ubyte(8);
        };

        // RLCA
        isaTable[0x07] = delegate() {
            r.af.a = rol(r.af.a, 1);
            r.af.f = 0;
            if (r.af.a & 0x01) {
                r.af.a = r.af.a & 0xFE;
                r.af.f |= FC;
            }
            if (r.af.a == 0) {
                r.af.f |= FZ;
            }
            return ubyte(4);
        };

        // LD (a16),SP
        isaTable[0x08] = delegate() {
            memory.write16(memory.read16(r.pc), r.sp);
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
            r.af.a = memory.read8(r.bc.v);
            return ubyte(8);
        };

        // DEC BC
        isaTable[0x0b] = delegate() {
            dec16(r.bc.v, r.af.f);
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
            r.bc.c = memory.read8(r.pc);
            r.pc += 1;
            return ubyte(8);
        };

        // RRCA
        isaTable[0x0f] = delegate() {
            r.af.a = ror(r.af.a, 1);
            r.af.f = 0;
            if (r.af.a & 0x80) {
                r.af.a = r.af.a & 0x7F;
                r.af.f |= FC;
            }
            if (r.af.a == 0) {
                r.af.f |= FZ;
            }
            return ubyte(4);
        };
    }

    unittest {
        Cpu cpu = new Cpu();
        cpu.r.af.a = 0x80;
        cpu.isaTable[0x07](); // rlca
        assert(cpu.r.af.a == 0x00);
        assert(cpu.r.af.f == (Cpu.FZ|Cpu.FC));
    }

    unittest {
        Cpu cpu = new Cpu();
        cpu.r.af.a = 0x01;
        cpu.isaTable[0x0f](); // rrca
        assert(cpu.r.af.a == 0x00);
        assert(cpu.r.af.f == (Cpu.FZ|Cpu.FC));
    }

    // auxiliary methods

    private static pure void inc8(ref ubyte r, ref ubyte f) {
        r += 1;
        // TODO: Handle flag set
    }

    private static pure void inc16(ref ushort r, ref ubyte f) {
        r += 1;
        // TODO: Handle flag set
    }

    private static pure void dec8(ref ubyte r, ref ubyte f) {
        r -= 1;
        // TODO: Handle flag set
    }

    private static pure void dec16(ref ushort r, ref ubyte f) {
        r -= 1;
        // TODO: Handle flag set
    }

    private static pure void add8(ref ubyte acc, ubyte arg, ref ubyte f) {
        acc += arg;
        // TODO: Handle flag set
    }

    private static pure void add16(ref ushort acc, ushort arg, ref ubyte f) {
        acc += arg;
        // TODO: Handle flag set
    }

}
