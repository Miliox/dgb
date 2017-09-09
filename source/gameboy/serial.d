module gameboy.serial;

import std.bitmanip;
import std.stdio;

class Serial
{
    union SerialControl
    {
        ubyte value;
        mixin(bitfields!(
            bool,  "clock", 1,   // Use internal clock when true else external
            ubyte, "",      6,   // Unused
            bool,  "start", 1)); // set back to zero when transfer finishes
    }

    private ubyte data;
    private SerialControl control;

    this() {
        data = 0xff;
        control.value = 0xff;
        control.start = false;
        control.clock = false;
    }

    ubyte sb()
    {
        return 0xff; // no other gameboy present so always return FF
    }

    void sb(ubyte sb)
    {
        data = sb;
    }

    ubyte sc()
    {
        return control.value;
    }

    void sc(ubyte sc)
    {
        bool transfer = control.start;
        bool clockSrc = control.clock;
        control.value = sc;

        //if (!transfer && control.start)
        //{
        //    writeln("serial transfer: ", control.start ? "start" : "stop");
        //}
        //else
        //{
        //    control.start = transfer;
        //}

        //if (clockSrc != control.clock)
        //{
        //    writeln("serial clock: ", control.clock ? "internal" : "external");
        //}
    }

    private int bitcounter = 0;
    private int bytecounter = 0;

    void addTicks(ubyte elapsed)
    {
        if (control.clock && control.start)
        {
            bitcounter += elapsed;
            bytecounter += elapsed;

            if (bitcounter >= 512)
            {
                bitcounter -= 512;
                data <<= 1;
                data |= 1;
            }

            if (bytecounter >= 4096)
            {
                control.start = false;
            }
        }
    }
}
