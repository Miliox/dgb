import std.stdio;
import std.file;
import core.thread;

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

class Emulator : Thread
{
    shared bool running;

    private Cpu cpu;
    private Gpu gpu;
    private Rom rom;
    private Timer timer;

    void delegate() onStop;

    this(string filepath) {
        super(&run);

        rom = new Rom();
        rom.load(filepath);

        cpu = new Cpu();
        gpu = new Gpu();
        timer = new Timer();

        Mmu mmu = new Mmu();
        mmu.cpu(cpu);
        mmu.gpu(gpu);
        mmu.rom(rom);
        mmu.timer(timer);

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
        gpu.onFrameReady = (ref ubyte[][] frame) {
            // TODO: Forward to GUI
        };
    }

    private void run()
    {
        running = true;
        while (running) {
            if (cpu.registers().pc == 0x100)
            {
                // Stop execution for now
                writeln("nintendo check: passed");
                running = false;
                break;
            }

            ubyte cycles = cpu.step();
            gpu.addTicks(cycles);
            timer.addTicks(cycles);
        }
        onStop();
    }

    void stop()
    {
        running = false;
        join();
    }
}
