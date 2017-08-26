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
