module gameboy.register;

import std.bitmanip;

align(2):
union AF {
    align(1):
    struct {
        ubyte f;
        ubyte a;
    }
    ushort v;
};

align(2):
union BC {
    align(1):
    struct {
        ubyte c;
        ubyte b;
    }
    ushort v;
};

align(2):
union DE {
    align(1):
    struct {
        ubyte e;
        ubyte d;
    }
    ushort v;
};

align(2):
union HL {
    align(1):
    struct {
        ubyte l;
        ubyte h;
    }
    ushort v;
};

static struct Registers
{
    AF af;
    BC bc;
    DE de;
    HL hl;
    ushort sp;  // special
    ushort pc;  // program counter

    unittest {
        Registers r;
        r.af.v = 0xDEAD;
        r.bc.v = 0xABCD;
        r.hl.h = 0xFF;
        r.hl.l = 0x00;

        assert(r.af.a == 0xDE);
        assert(r.af.f == 0xAD);
        assert(r.bc.b == 0xAB);
        assert(r.bc.c == 0xCD);
        assert(r.hl.v == 0xFF00);
    }
}

union Lcdc
{
    enum SpriteSize : bool {
        SIZE_8_8 = 0,
        SIZE_8_16 = 1
    }

    enum BgTileMapAddressArea : bool {
        BTMA_9800_9BFF = 0,
        BTMA_9C00_9FFF = 1
    }

    enum BgTileDataAddressArea : bool {
        BTDAA_8800_97FF = 0,
        BTDAA_8000_8FFF = 1
    }

    enum WindowTileDataAddressArea : bool {
        WTDAA_9800_9BFF = 0,
        WTDAA_9C00_9FFF = 1
    }

    /*
        FF40 - LCDC - LCD Control (R/W)

        Bit 7 - LCD Display Enable             (0=Off, 1=On)
        Bit 6 - Window Tile Map Display Select (0=9800-9BFF, 1=9C00-9FFF)
        Bit 5 - Window Display Enable          (0=Off, 1=On)
        Bit 4 - BG & Window Tile Data Select   (0=8800-97FF, 1=8000-8FFF)
        Bit 3 - BG Tile Map Display Select     (0=9800-9BFF, 1=9C00-9FFF)
        Bit 2 - OBJ (Sprite) Size              (0=8x8, 1=8x16)
        Bit 1 - OBJ (Sprite) Display Enable    (0=Off, 1=On)
        Bit 0 - BG Display (for CGB see below) (0=Off, 1=On)

        FF40 -- LCDCONT [RW] LCD Control              | when set to 1 | when set to 0
        Bit7  LCD operation                           | ON            | OFF
        Bit6  Window Tile Table address               | 9C00-9FFF     | 9800-9BFF
        Bit5  Window display                          | ON            | OFF
        Bit4  Tile Pattern Table address              | 8000-8FFF     | 8800-97FF
        Bit3  Background Tile Table address           | 9C00-9FFF     | 9800-9BFF
        Bit2  Sprite size                             | 8x16          | 8x8
        Bit1  Color #0 transparency in the window     | SOLID         | TRANSPARENT
        Bit0 Background display | ON | OFF
     */

    ubyte value;
    mixin(bitfields!(
        bool,                      "bgOn",        1, // CG only
        bool,                      "spriteOn",    1,
        SpriteSize,                "spriteSize",  1,
        BgTileMapAddressArea,      "bgTileMap",   1,
        BgTileDataAddressArea,     "bgTileData",  1,
        bool,                      "winOn",       1,
        WindowTileDataAddressArea, "winTileData", 1,
        bool,                      "lcdOn",       1));

    ubyte get() {
        return value;
    }

    void set(ubyte value) {
        this.value = value;
    }
}

union Stat
{
    /*
        FF41 - STAT - LCDC Status (R/W)

        Bit 6 - LYC=LY Coincidence Interrupt (1=Enable) (Read/Write)
        Bit 5 - Mode 2 OAM Interrupt         (1=Enable) (Read/Write)
        Bit 4 - Mode 1 V-Blank Interrupt     (1=Enable) (Read/Write)
        Bit 3 - Mode 0 H-Blank Interrupt     (1=Enable) (Read/Write)
        Bit 2 - Coincidence Flag  (0:LYC<>LY, 1:LYC=LY) (Read Only)
        Bit 1-0 - Mode Flag       (Mode 0-3, see below) (Read Only)
            0: During H-Blank
            1: During V-Blank
            2: During Searching OAM-RAM
            3: During Transfering Data to LCD Driver


        FF41 -- LCDSTAT [RW] LCD Status               | when set to 1 | when set to 0
        Bit6    Interrupt on scanline coincidence     | ON            | OFF
        Bit5    Interrupt on controller mode 10       | ON            | OFF
        Bit4    Interrupt on controller mode 01       | ON            | OFF
        Bit3    Interrupt on controller mode 00       | ON            | OFF
        Bit2    Scanline coincidence flag             | COINCIDENCE   | NO COINCIDENCE
        Bit1-0  LCD Controller mode:
        00 - Horizontal blanking impulse [VRAM 8000-9FFF can be accessed by CPU]
        01 - Vertical blanking impulse [VRAM 8000-9FFF can be accessed by CPU]
        10 - OAM FE00-FE90 is accessed by LCD controller
        11 - Both OAM FE00-FE90 and VRAM 8000-9FFF are accessed by LCD controller
     */

    enum Mode : ubyte {
        HBLANK = 0,
        VBLANK = 1,
        OAM_READ = 2,
        TRANSFER = 3
    }

    ubyte value;

    mixin(bitfields!(
        Mode, "mode",            2, // Read Only
        bool, "yCoincidence",    1, // Read Only
        bool, "intHBlank",       1,
        bool, "intVBlank",       1,
        bool, "intOAMRead",      1,
        bool, "intYCoincidence", 1,
        bool, "", 1));

    enum ubyte writeMask = 0xfc;

    ubyte get() {
        return value;
    }

    void set(ubyte value) {
        this.value &= ~writeMask;
        this.value |= value & writeMask;
    }
}

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

union JoypadRegister
{
    ubyte value;

    mixin(bitfields!(
        bool, "p10", 1, // R   Input Right or Button A (0=Pressed)
        bool, "p11", 1, // R   Input Left or Button B  (0=Pressed)
        bool, "p12", 1, // R   Input Up or Select      (0=Pressed)
        bool, "p13", 1, // R   Input Down or Start     (0=Pressed)
        bool, "p14", 1, // RW  Select Direction Keys   (0=Select)
        bool, "p15", 1, // RW  Select Button Keys      (0=Select)
        byte, "nu",  2));  //  Not Used

    mixin(bitfields!(
        bool, "a",      1,
        bool, "b",      1,
        bool, "select", 1,
        bool, "start",  1,
        bool, "",       1,
        bool, "button", 1,
        byte, "",       2));

    mixin(bitfields!(
        bool, "right",  1,
        bool, "left",   1,
        bool, "up",     1,
        bool, "down",   1,
        bool, "dpad",   1,
        bool, "", 1,
        byte, "",       2));

    enum ubyte writeMask = 0xf0;

    void set(ubyte value)
    {
        this.value &= ~writeMask;
        this.value |= value & writeMask;
    }

    ubyte get()
    {
        return this.value;
    }
}
