interface Memory
{
    ubyte  read8(ushort address);
    ushort read16(ushort address);

    void write8(ushort address, ubyte data);
    void write16(ushort address, ushort data);
}

class NoMemory : Memory
{
    ubyte read8(ushort)
    {
        // Nothing to do
        return 0;
    }

    ushort read16(ushort)
    {
        // Nothing to do
        return 0;
    }

    void write8(ushort, ubyte)
    {
        // Nothing to do
    }

    void write16(ushort, ushort)
    {
        // Nothing to do
    }
}
