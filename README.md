# D Gameboy Emulator

A gameboy emulator written in D.

## Build & Run

```sh
# Clean
dub clean

# Build
dub build
./dgb <rom>.gb

# Unit Tests
dub test
./dgb-test-library
```

## Requirements

* SDL2

## Progress

- [X] CPU Registers
- [X] CPU Instructions
- [X] CPU Interruption Handle
- [X] CPU Internal Flags
- [X] Debugger Instruction
- [X] Debugger Registers
- [ ] Debugger Memory
- [ ] Debugger Break
- [X] Debugger Step
- [X] Execution Cycle
- [X] Execution Clock Sync
- [X] Memory Common Interface
- [ ] Memory Management Unit (WIP)
- [X] Timer Controller
- [X] BIOS Check Pass
- [X] Cartridge Load
- [X] GPU Timing
- [ ] GPU Background Render
- [ ] GPU Sprite Render
- [X] Window & Media Library (SDL2)
- [ ] Sound Controller
- [ ] Keyboard Input
- [ ] Serial Controller
- [ ] Cartridge Controller
- [ ] Cartridge Bank Switch
- [ ] Cartridge RAM
