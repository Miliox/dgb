module gameboy.memory;

struct MemoryMapInfo
{
    immutable ushort begin;
    immutable ushort end;

    this(ushort begin, ushort end)
    {
        this.begin = begin;
        this.end = end;
    }

    @property size_t size()
    {
        return begin + 1 - end;
    }

    @property bool contains(ushort addr)
    {
        return addr >= begin && addr <= end;
    }
}

enum MemoryMap : MemoryMapInfo
{
    RestartAndIntVectors = MemoryMapInfo(0x0000, 0x00FF),
    CartridgeHeader      = MemoryMapInfo(0x0100, 0x014F),
    CartridgeBank0       = MemoryMapInfo(0x0150, 0x3FFF),
    CartridgeBank1       = MemoryMapInfo(0x4000, 0x7FFF),
    CharacterRAM         = MemoryMapInfo(0x8000, 0x97FF),
    BackgroundMapData1   = MemoryMapInfo(0x9800, 0x9BFF),
    BackgroundMapData2   = MemoryMapInfo(0x9C00, 0x9FFF),
    CartridgeRAM         = MemoryMapInfo(0xA000, 0xBFFF),
    InternalRAMBankN     = MemoryMapInfo(0xC000, 0xCFFF),
    InternalRAMBank0     = MemoryMapInfo(0xD000, 0xDFFF),
    EchoRAM              = MemoryMapInfo(0xE000, 0xFDFF),
    ObjAttrMemory        = MemoryMapInfo(0xFE00, 0xFE9F),
    UnusableMemory       = MemoryMapInfo(0xFEA0, 0xFEFF),
    HardwareIOMap        = MemoryMapInfo(0xFF00, 0xFF7F),
    HighRAM              = MemoryMapInfo(0xFF80, 0xFFFE),
    InterruptEnableAddr  = MemoryMapInfo(0xFFFF, 0xFFFF)
}

interface Memory
{
    ubyte read8(ushort address);
    void  write8(ushort address, ubyte data);
}

class NoMemory : Memory
{
    ubyte read8(ushort)
    {
        // Nothing to do
        return 0;
    }

    void write8(ushort, ubyte)
    {
        // Nothing to do
    }

}
