import memory;

import std.stdio;

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
        ubyte opcode = memory.read(r.pc++);

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

    // Instruction Set

    ubyte nop()
    {
        return 4;
    }

    // Instruction Helpers

    // Helpers

    void fillIsa()
    {
        // TODO: Populate ISA Table
        isaTable[0x00] = &nop;
    }
}
