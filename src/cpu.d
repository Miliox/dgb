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

    private bool ime = false;      // interrupt master enable flag
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
        r.de.v = 0;
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
            r.bc.b = memory.read8(r.pc);
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
            r.bc.c = memory.read8(r.pc);
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
            ubyte arg = memory.read8(r.pc++);
            assert(arg == 0);
            stopped = true;
            return ubyte(4);
        };

        // LD DE,d16
        isaTable[0x11] = delegate() {
            r.de.v = memory.read16(r.pc);
            r.pc += 2;
            return ubyte(12);
        };

        // LD (DE),A
        isaTable[0x12] = delegate() {
            memory.write8(r.de.v, r.af.a);
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
            r.de.d = memory.read8(r.pc++);
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
            byte offset = cast(byte) memory.read8(r.pc++);
            jr8(r.pc, offset);
            return ubyte(12);
        };

        // ADD HL,DE
        isaTable[0x19] = delegate() {
            add16(r.hl.v, r.de.v, r.af.f);
            return ubyte(8);
        };

        // LD A,(DE)
        isaTable[0x1a] = delegate() {
            r.af.a = memory.read8(r.de.v);
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
            r.de.e = memory.read8(r.pc++);
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
            byte offset = cast(byte) memory.read8(r.pc++);
            if ((r.af.f & FLAG_ZERO) == 0) {
                jr8(r.pc, offset);
                return ubyte(12);
            }
            return ubyte(8);
        };

        // LD HL,d16
        isaTable[0x21] = delegate() {
            r.hl.v = memory.read16(r.pc);
            r.pc += 2;
            return ubyte(8);
        };

        // LD (HL+),A
        isaTable[0x22] = delegate() {
            memory.write8(r.hl.v++, r.af.a);
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
            r.hl.h = memory.read8(r.pc++);
            return ubyte(8);
        };

        // DAA
        isaTable[0x27] = delegate() {
            daa8(r.af.a, r.af.f);
            return ubyte(4);
        };

        // JR Z,r8
        isaTable[0x28] = delegate() {
            byte offset = cast(byte) memory.read8(r.pc++);
            if ((r.af.f & FLAG_ZERO) != 0) {
                jr8(r.pc, offset);
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
            r.af.a = memory.read8(r.hl.v++);
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
            r.hl.l = memory.read8(r.pc++);
            return ubyte(8);
        };

        // CPL
        isaTable[0x2f] = delegate() {
            cpl8(r.af.a, r.af.f);
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

    // jump relative
    private static pure void jr8(ref ushort pc, byte offset)
    {
        pc += offset;
    }

    unittest
    {
        ushort pc = 1000;
        jr8(pc, 10);
        assert(pc == 1010);

        pc = 2000;
        jr8(pc, -20);
        assert(pc == 1980);
    }
}
