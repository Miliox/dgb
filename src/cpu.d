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
    private static immutable ubyte FLAG_ZERO  = 1 << 7; // zero flag
    private static immutable ubyte FLAG_NEG   = 1 << 6; // add-sub flag (bcd)
    private static immutable ubyte FLAG_HALF  = 1 << 5; // half carry flag (bcd)
    private static immutable ubyte FLAG_CARRY = 1 << 4; // carry flag

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
                setFlag(r.af.f, FLAG_CARRY);
            }
            if (r.af.a == 0) {
                setFlag(r.af.f, FLAG_ZERO);
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
                setFlag(r.af.f, FLAG_CARRY);
            }
            if (r.af.a == 0) {
                setFlag(r.af.f, FLAG_ZERO);
            }
            return ubyte(4);
        };
    }

    unittest {
        Cpu cpu = new Cpu();
        cpu.r.af.a = 0x80;
        cpu.isaTable[0x07](); // rlca
        assert(cpu.r.af.a == 0x00);
        assert(cpu.r.af.f == (Cpu.FLAG_ZERO|Cpu.FLAG_CARRY));
    }

    unittest {
        Cpu cpu = new Cpu();
        cpu.r.af.a = 0x01;
        cpu.isaTable[0x0f](); // rrca
        assert(cpu.r.af.a == 0x00);
        assert(cpu.r.af.f == (Cpu.FLAG_ZERO|Cpu.FLAG_CARRY));
    }

    // auxiliary methods

    /// set bitflag to flags
    private static pure void setFlag(ref ubyte flags, ubyte bitflag) {
        flags |= bitflag;
    }

    unittest
    {
        ubyte flags = 0x80;
        setFlag(flags, 0x04);
        assert(flags == 0x84);
    }

    /// reset bitflag on flags
    private static pure void resetFlag(ref ubyte flags, ubyte bitflag) {
        flags &= ~bitflag;
    }

    unittest
    {
        ubyte flags = 0xff;
        resetFlag(flags, 0x88);
        assert(flags == 0x77);
    }

    // 8 bits arithmetics

    /// add for 8 bits registers
    private static pure void add8(ref ubyte acc, ubyte reg, ref ubyte f) {
        bool halfCarry = ((acc & 0xf) + (reg & 0xf)) > 0xf;  // carry from bit 3
        bool fullCarry = (ushort(acc) + ushort(reg)) > 0xff; // carry from bit 7
        acc += reg;

        resetFlag(f, FLAG_NEG);

        if (acc == 0)
        {
            setFlag(f, FLAG_ZERO);
        }

        if (halfCarry)
        {
            setFlag(f, FLAG_HALF);
        }

        if (fullCarry)
        {
            setFlag(f, FLAG_CARRY);
        }
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

        resetFlag(f, FLAG_NEG);

        if (acc == 0)
        {
            setFlag(f, FLAG_ZERO);
        }

        if (halfCarry)
        {
            setFlag(f, FLAG_HALF);
        }

        if (fullCarry)
        {
            setFlag(f, FLAG_CARRY);
        }
    }

    unittest
    {
        // test carry increment
        ubyte acc = 0;
        ubyte reg = 0;
        ubyte flags = (FLAG_NEG | FLAG_CARRY); // must be reset
        adc8(acc, reg, flags);
        assert(acc == 1);
        assert(flags == FLAG_CARRY);

        // test half carry and carry increment
        acc = 1; reg = 127; flags = FLAG_CARRY;
        adc8(acc, reg, flags);
        assert(acc == 129);
        assert(flags == (FLAG_HALF | FLAG_CARRY));

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

        setFlag(f, FLAG_NEG);

        if (acc == 0)
        {
            setFlag(f, FLAG_ZERO);
        }

        if (halfCarry)
        {
            setFlag(f, FLAG_HALF);
        }

        if (fullCarry)
        {
            setFlag(f, FLAG_CARRY);
        }
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
        assert(flags == (FLAG_NEG | FLAG_CARRY));

        acc = 0xf0; reg = 0x80; flags = FLAG_CARRY;
        sbc8(acc, reg, flags);
        assert(acc == 0x6f);
        assert(flags == (FLAG_NEG | FLAG_CARRY));
    }

    // and for 8 bit registers
    private static pure void and8(ref ubyte acc, ubyte reg, ref ubyte f)
    {
        acc &= reg;

        resetFlag(f, FLAG_NEG | FLAG_CARRY);
        setFlag(f, FLAG_HALF);

        if (acc == 0)
        {
            setFlag(f, FLAG_ZERO);
        }
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

        resetFlag(f, FLAG_NEG | FLAG_HALF | FLAG_CARRY);
        if (acc == 0)
        {
            setFlag(f, FLAG_ZERO);
        }
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

        resetFlag(f, FLAG_NEG | FLAG_HALF | FLAG_CARRY);
        if (acc == 0)
        {
            setFlag(f, FLAG_ZERO);
        }
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
            setFlag(f, FLAG_CARRY);
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

        resetFlag(f, FLAG_NEG);

        if (halfCarry)
        {
            setFlag(f, FLAG_HALF);
        }

        if (r == 0)
        {
            setFlag(f, FLAG_ZERO);
        }
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

    private static pure void dec8(ref ubyte r, ref ubyte f) {
        bool halfCarry = (r & 0xf) == 0;
        r -= 1;

        setFlag(f, FLAG_NEG);

        if (halfCarry)
        {
            setFlag(f, FLAG_HALF);
        }

        if (r == 0)
        {
            setFlag(f, FLAG_ZERO);
        }
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
    private static pure void add16(ref ushort acc, ushort reg, ref ubyte f) {
        bool halfCarry = ((acc & 0xfff) + (reg & 0xfff)) > 0xfff;  // carry from bit 11
        bool fullCarry = (uint(acc) + uint(reg)) > 0xffff;         // carry from bit 15

        acc += reg;

        resetFlag(f, FLAG_NEG);

        if (halfCarry)
        {
            setFlag(f, FLAG_HALF);
        }

        if (fullCarry)
        {
            setFlag(f, FLAG_CARRY);
        }
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
    private static pure void inc16(ref ushort r, ref ubyte f) {
        r += 1;
        // No flag effects
    }

    // dec for 16 bits registers
    private static pure void dec16(ref ushort r, ref ubyte f) {
        r -= 1;
        // No flag effects
    }

}
