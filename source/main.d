import frontend;
import backend;
import std.stdio;

import debugger;
import memory;

void main(string[] args)
{
    if (args.length != 2) {
        writeln("err: path to rom file not provided!");
        return;
    }

    FrontEnd front = new FrontEnd(4);
    BackEnd back = new BackEnd(args[1]);
    back.onStop = {
        front.stop();
    };
    back.start();

    front.run();
    back.stop();
}
