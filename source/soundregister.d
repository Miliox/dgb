import std.bitmanip;

union Sr10
{
    ubyte value;

    mixin(bitfields!(
        ubyte, "sweepShift", 3,   // RW
        ubyte, "sweepDir",   1,   // RW
        ubyte, "sweepTime",  3,   // RW
        ubyte, "reserved",   1)); // R

    enum ubyte writeMask = 0x7f, readMask = 0x80;

    ubyte get() {
        return this.value | readMask;
    }

    void set(ubyte value) {
        this.value &= ~writeMask;
        this.value |= value & writeMask;
    }
}

unittest
{
    Sr10 sr10;

    // test msb
    sr10.reserved = 1;
    assert(sr10.value == 0x80);

    // test write routine
    sr10.set(0x35);
    assert(sr10.reserved  == 1);
    assert(sr10.sweepTime == 3);
    assert(sr10.sweepDir  == 0);
    assert(sr10.sweepShift == 5);

    // test read routine
    sr10.value = 0;
    assert(sr10.get() == 0x80);
}

union Sr11 {
    ubyte value;
    mixin(bitfields!(
        ubyte, "waveDuty",    6,    // RW
        ubyte, "soundLength", 2));  // W

    enum ubyte writeMask = 0xff, readMask = 0x03;

    ubyte get() {
        return this.value | readMask;
    }

    void set(ubyte value) {
        this.value &= ~writeMask;
        this.value |= value & writeMask;
    }
}

union Sr12 {
    ubyte value;
    mixin(bitfields!(
        ubyte, "envelopeCount",     3,   // RW
        ubyte, "envelopeDirection", 1,   // RW
        ubyte, "initialVolume",     4)); // RW

    enum ubyte writeMask = 0xff, readMask = 0xff;

    ubyte get() {
        return this.value | readMask;
    }

    void set(ubyte value) {
        this.value &= ~writeMask;
        this.value |= value & writeMask;
    }
}

union Sr13 {
    ubyte value;
    mixin(bitfields!(ubyte, "frequencyLsb", 8)); // W

    enum ubyte writeMask = 0xff, readMask = 0x00;

    ubyte get() {
        return this.value | readMask;
    }

    void set(ubyte value) {
        this.value &= ~writeMask;
        this.value |= value & writeMask;
    }
}

union Sr14 {
    ubyte value;
    mixin(bitfields!(
        ubyte, "frequencyMsb",      3,   // W
        ubyte, "envelopeDirection", 1,   // RW
        ubyte, "initialVolume",     4)); // W

    enum ubyte writeMask = 0xff, readMask = 0x10;

    ubyte get() {
        return this.value | readMask;
    }

    void set(ubyte value) {
        this.value &= ~writeMask;
        this.value |= value & writeMask;
    }
}

alias Sr21 = Sr11;
alias Sr22 = Sr12;
alias Sr23 = Sr13;
alias Sr24 = Sr14;

union Sr30 {
    ubyte value;
    mixin(bitfields!(
        ubyte, "reserved", 7,   // R
        bool,  "soundOn",  1)); // W

    enum ubyte writeMask = 0x80, readMask = 0x7f;

    ubyte get() {
        return this.value | readMask;
    }

    void set(ubyte value) {
        this.value &= ~writeMask;
        this.value |= value & writeMask;
    }
}

union Sr31 {
    ubyte value;
    mixin(bitfields!(
        ubyte, "soundLength", 8)); // RW?

    enum ubyte writeMask = 0xff, readMask = 0x00;

    ubyte get() {
        return this.value | readMask;
    }

    void set(ubyte value) {
        this.value &= ~writeMask;
        this.value |= value & writeMask;
    }
}

union Sr32 {
    ubyte value;
    mixin(bitfields!(
        ubyte, "lreserved",   4,
        ubyte, "outputLevel", 2,
        ubyte, "hreserved",   2));

    enum ubyte writeMask = 0x30, readMask = 0xcf;

    ubyte get() {
        return this.value | readMask;
    }

    void set(ubyte value) {
        this.value &= ~writeMask;
        this.value |= value & writeMask;
    }
}

alias Sr33 = Sr13;
alias Sr34 = Sr14;

union Sr41 {
    ubyte value;
    mixin(bitfields!(
        ubyte, "soundLength", 6,  // RW
        ubyte, "reserved",    2));

    enum ubyte writeMask = 0x3f, readMask = 0xc0;

    ubyte get() {
        return this.value | readMask;
    }

    void set(ubyte value) {
        this.value &= ~writeMask;
        this.value |= value & writeMask;
    }
}

alias Sr42 = Sr12;

union Sr43 {
    ubyte value;
    mixin(bitfields!(
        ubyte, "divRatio",    3,   // RW
        ubyte, "counterStep", 1,   // RW
        ubyte, "shiftFreq",   4)); // RW

    enum ubyte writeMask = 0xff, readMask = 0x00;

    ubyte get() {
        return this.value | readMask;
    }

    void set(ubyte value) {
        this.value &= ~writeMask;
        this.value |= value & writeMask;
    }
}

union Sr44 {
    ubyte value;
    mixin(bitfields!(
        ubyte, "reserved",  6,
        ubyte, "selector",  1,   // RW
        ubyte, "restart",   1)); // W

    enum ubyte writeMask = 0x40, readMask = 0xbf;

    ubyte get() {
        return this.value | readMask;
    }

    void set(ubyte value) {
        this.value &= ~writeMask;
        this.value |= value & writeMask;
    }
}

union Sr50 {
    ubyte value;
    mixin(bitfields!(
        ubyte, "so1Volume",  3, // RW
        bool,  "so1Enable",  1, // RW
        ubyte, "so2Volume",  3, // RW
        bool,  "so2Enable",  1)); // RW

    enum ubyte writeMask = 0xff, readMask = 0x00;

    ubyte get() {
        return this.value | readMask;
    }

    void set(ubyte value) {
        this.value &= ~writeMask;
        this.value |= value & writeMask;
    }
}

union Sr51 {
    ubyte value;
    mixin(bitfields!(
        bool, "ch1ToSo1",  1, // RW
        bool, "ch2ToSo1",  1, // RW
        bool, "ch3ToSo1",  1, // RW
        bool, "ch4ToSo1",  1, // RW
        bool, "ch1ToSo2",  1, // RW
        bool, "ch2ToSo2",  1, // RW
        bool, "ch3ToSo2",  1, // RW
        bool, "ch4ToSo2",  1)); // RW

    enum ubyte writeMask = 0xff, readMask = 0x00;

    ubyte get() {
        return this.value | readMask;
    }

    void set(ubyte value) {
        this.value &= ~writeMask;
        this.value |= value & writeMask;
    }
}

union Sr52 {
    ubyte value;
    mixin(bitfields!(
        bool, "ch1Enable",  1, // R
        bool, "ch2Enable",  1, // R
        bool, "ch3Enable",  1, // R
        bool, "ch4Enable",  1, // R
        ubyte, "reserved",  3,
        bool, "soundOn",  1)); // RW

    enum ubyte writeMask = 0x8f, readMask = 0x70;

    ubyte get() {
        return this.value | readMask;
    }

    void set(ubyte value) {
        this.value &= ~writeMask;
        this.value |= value & writeMask;
    }
}
