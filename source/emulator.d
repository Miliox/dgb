import std.stdio;
import std.file;

import core.time;
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
    shared bool sync = true;

    private Cpu cpu;
    private Gpu gpu;
    private Rom rom;
    private Timer timer;

    void delegate() onStop;

    private immutable int TICKS_PER_SECOND = 4194304;
    private immutable int TICKS_PER_FRAME  = 70224;

    private immutable Duration FRAME_PERIOD = dur!"nsecs"(16742706); // (TICKS_PER_FRAME / TICKS_PER_SECOND)

    // Clock synchronization timers
    private MonoTime frameTimestamp; // mark the begining of a frame
    private Duration delayOversleep; // needed to compensate imprecisions of sleep()

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

    /// Sync gameboy original clock with this system clock on frame units
    private void syncFrame() {
        auto idleTimestamp = MonoTime.currTime;
        auto delay = FRAME_PERIOD - (idleTimestamp - frameTimestamp) - delayOversleep;

        if (sync) {
            sleep(delay);
        }

        frameTimestamp = MonoTime.currTime;
        delayOversleep = sync ? ((frameTimestamp - idleTimestamp) - delay) : Duration.zero;
    }

    private void run()
    {
        running = true;

        frameTimestamp = MonoTime.currTime;
        delayOversleep = Duration.zero;

        int tickCount = 0;
        while (running)
        {
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

            tickCount += cycles;
            if (tickCount >= TICKS_PER_FRAME) {
                tickCount -= TICKS_PER_FRAME;
                syncFrame();
            }
        }
        onStop();
    }

    void stop()
    {
        running = false;
        join();
    }
}
