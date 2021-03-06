module gameboy.joypad;

import gameboy.register;
import std.stdio;

class Joypad
{
    private JoypadRegister register;

    private bool buttonA;
    private bool buttonB;
    private bool buttonSelect;
    private bool buttonStart;

    private bool dpadUp;
    private bool dpadLeft;
    private bool dpadRight;
    private bool dpadDown;

    this() {
        register.value = 0xff;
    }

    ubyte p1() {
        return register.get();
    }

    void setDpad(bool up, bool left, bool right, bool down)
    {
        dpadUp    = up;
        dpadLeft  = left;
        dpadRight = right;
        dpadDown  = down;

        refreshState();
    }

    void setButtons(bool a, bool b, bool select, bool start)
    {
        buttonA = a;
        buttonB = b;

        buttonSelect = select;
        buttonStart  = start;

        refreshState();
    }

    void p1(ubyte p1) {
        register.set(p1);
        refreshState();
    }

    private void refreshState()
    {
        if (register.dpad && register.button)
        {
            register.p10 = !buttonA && !dpadUp;
            register.p11 = !buttonB && !dpadLeft;
            register.p12 = !buttonSelect && !dpadUp;
            register.p13 = !buttonStart  && !dpadDown;
        }
        else if (register.dpad)
        {
            register.up    = !dpadUp;
            register.left  = !dpadLeft;
            register.right = !dpadRight;
            register.down  = !dpadDown;
        }
        else if (register.button)
        {
            register.a = !buttonA;
            register.b = !buttonB;

            register.select = !buttonSelect;
            register.start  = !buttonStart;
        }
        else
        {
            register.p10 = true;
            register.p11 = true;
            register.p12 = true;
            register.p13 = true;
        }

    }
}

unittest
{
    Joypad joypad = new Joypad();
    assert(joypad.p1() == 0xff);

    joypad.setDpad(true, false, true, false); // up, left, right, down
    joypad.setButtons(false, true, false, true); // a, b, select, Start

    joypad.p1(1 << 4); // select dpad
    assert(joypad.p1() == 0b0001_1010);  // ~dulr

    joypad.p1(1 << 5); // select buttons
    assert(joypad.p1() == 0b0010_0101); // ~Ssba

    joypad.setButtons(false, false, true, false); // a, b, select, Start
    assert(joypad.p1() == 0b0010_1011); // ~Ssba
}
