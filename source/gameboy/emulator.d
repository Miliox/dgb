module gameboy.emulator;

import std.stdio;
import std.file;

import core.time;
import core.thread;

import gameboy.cpu;
import gameboy.gpu;
import gameboy.timer;
import gameboy.joypad;
import gameboy.mmu;
import gameboy.sound;
import gameboy.memory;

import util.debugger;

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
    private Mmu mmu;
    private Rom rom;
    private Timer timer;
    private Joypad joypad;
    private Sound sound;

    void delegate(ref ubyte[] frame) onFrame;
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
        joypad = new Joypad();
        timer = new Timer();
        sound = new Sound();

        mmu = new Mmu();
        mmu.cpu(cpu);
        mmu.gpu(gpu);
        mmu.rom(rom);
        mmu.joypad(joypad);
        mmu.timer(timer);
        mmu.sound(sound);

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
        gpu.onFrameReady = (ref ubyte[] frame) {
            onFrame(frame);
        };
    }

    /// Sync gameboy original clock with this system clock on frame units
    private void syncFrame() {
        auto idleTimestamp = MonoTime.currTime;
        auto delay = FRAME_PERIOD - (idleTimestamp - frameTimestamp) - delayOversleep;

        if (sync && delay > dur!("nsecs")(0)) {
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
            mmu.addTicks(cycles);
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
