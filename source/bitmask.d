module bitmask;

pure void set(ref ubyte value, ubyte mask)
{
    value |= mask;
}

pure void unset(ref ubyte value, ubyte mask)
{
    value &= ~mask;
}

// set mask if set else resets
static pure void setIf(ref ubyte value, ubyte mask, bool condition)
{
    if (condition)
    {
        set(value, mask);
    }
    else // reset
    {
        unset(value, mask);
    }
}

static pure bool check(ref ubyte value, ubyte mask)
{
    return (value & mask) == mask;
}

unittest
{
    ubyte flags = 0x80;
    setIf(flags, 0x04, true);
    assert(flags == 0x84);

    flags = 0xff;
    setIf(flags, 0x88, false);
    assert(flags == 0x77);
}
