import std.stdio;
import std.file;

import cpu;
import gpu;
import timer;
import mmu;

import debugger;
import memory;

class Rom : Memory
{
    private ubyte[] rom = new ubyte[0x8000];

    bool load(string path) {
        auto file = File(path, "r");
        try {
            file.rawRead(rom);
        }
        catch(FileException fe)
        {
            writefln("err: %s", fe.msg);
            return false;
        } finally
        {
            file.close();
        }
        return true;
    }

    ubyte read8(ushort address)
    {
        return rom[address & 0x7fff];
    }

    void write8(ushort address, ubyte data)
    {
        // read only
    }
}

void main(string[] args)
{
    Cpu cpu = new Cpu();
    Gpu gpu = new Gpu();
    Rom rom = new Rom();
    Timer timer = new Timer();

    if (args.length >= 2) {
        bool loaded = rom.load(args[1]);
        writefln("%s load %s!", args[1], loaded ? "success" : "fail");
    } else {
        writeln("no cartridge provided");
    }

    Mmu mmu = new Mmu();
    mmu.cpu(cpu);
    mmu.gpu(gpu);
    mmu.timer(timer);
    mmu.rom(rom);

    cpu.memory(mmu);
    timer.onInterrupt = {
        cpu.timerInt();
    };
    gpu.onVBlankInterrupt = {
        cpu.vblankInt();
    };
    gpu.onLcdcStatInterrupt = {
        cpu.lcdcInt();
    };

    Debugger debugger = new Debugger();
    debugger.cpu = cpu;

    for (;;) {
        debugger.dumpR();
        write(" ");
        debugger.dumpI();
        getchar();

        ubyte cycles = cpu.step();
        gpu.addTicks(cycles);
        timer.addTicks(cycles);
    }
}
