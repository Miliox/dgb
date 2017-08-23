import memory;

align(16):
union AF {
    align(8):
    struct {
        ubyte f;
        ubyte a;
    }
    ushort v;
};
align(16):
union BC {
    align(8):
    struct {
        ubyte c;
        ubyte b;
    }
    ushort v;
};

align(16):
union HL {
    align(8):
    struct {
        ubyte h;
        ubyte l;
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
