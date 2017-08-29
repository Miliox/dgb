import std.stdio;

import cpu;
import timer;
import mmu;

import debugger;
import memory;

void main()
{
    Cpu cpu = new Cpu();
    Timer timer = new Timer();

    Mmu mmu = new Mmu();
    mmu.cpu(cpu);
    mmu.timer(timer);

    cpu.memory(mmu);

    Debugger debugger = new Debugger();
    debugger.cpu = cpu;

    for (;;) {
        debugger.dumpR();
        write(" ");
        debugger.dumpI();
        getchar();
        cpu.step();
    }
}
