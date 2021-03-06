import gui;
import gameboy.emulator;
import std.stdio;

void main(string[] args)
{
    if (args.length != 2) {
        writeln("err: path to rom file not provided!");
        return;
    }

    Gui gui = new Gui(4);
    Emulator emulator = new Emulator(args[1]);

    emulator.onFrame = (ref ubyte[] frame) {
        gui.putFrame(frame);
    };
    emulator.onStop = {
        gui.stop();
    };
    emulator.start();

    gui.run();
    emulator.stop();
}
