interface Memory
{
    ubyte read(ushort address);
    void write(ushort address, ubyte data);
    void write(ushort address, ushort data);
}

class NoMemory : Memory
{
    ubyte read(ushort)
    {
        // Nothing to do
        return 0;
    }

    void write(ushort, ubyte)
    {
        // Nothing to do
    }

    void write(ushort, ushort)
    {
        // Nothing to do
    }
}
