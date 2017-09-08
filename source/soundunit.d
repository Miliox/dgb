import soundregister;

class SoundUnit
{
    private Sr10 m_sr10; // Channel 1 Sweep register (R/W)
    private Sr11 m_sr11; // Channel 1 Sound length/Wave pattern duty (R/W)
    private Sr12 m_sr12; // Channel 1 Volume Envelope (R/W)
    private Sr13 m_sr13; // Channel 1 Frequency lo (Write Only)
    private Sr14 m_sr14; // Channel 1 Frequency hi (R/W)

    private Sr21 m_sr21; // Channel 2 Sound Length/Wave Pattern Duty (R/W)
    private Sr22 m_sr22; // Channel 2 Volume Envelope (R/W)
    private Sr23 m_sr23; // Channel 2 Frequency lo data (W)
    private Sr24 m_sr24; // Channel 2 Frequency hi data (R/W)

    private Sr30 m_sr30; // Channel 3 Sound on/off (R/W)
    private Sr31 m_sr31; // Channel 3 Sound Length
    private Sr32 m_sr32; // Channel 3 Select output level (R/W)
    private Sr33 m_sr33; // Channel 3 Frequency's lower data (W)
    private Sr34 m_sr34; // Channel 3 Frequency's higher data (R/W)

    private Sr41 m_sr41; // Channel 4 Sound Length (R/W)
    private Sr42 m_sr42; // Channel 4 Volume Envelope (R/W)
    private Sr43 m_sr43; // Channel 4 Polynomial Counter (R/W)
    private Sr44 m_sr44; // Channel 4 Counter/consecutive; Inital (R/W)

    private Sr50 m_sr50; // Channel control / ON-OFF / Volume (R/W)
    private Sr51 m_sr51; // Selection of Sound output terminal (R/W)
    private Sr52 m_sr52; // NR52 - Sound on/off

    private ubyte[16] m_wave; // Wave Pattern RAM

    ubyte sr10()
    {
        return m_sr10.get();
    }

    void sr10(ubyte sr10)
    {
        m_sr10.set(sr10);
    }

    ubyte sr11()
    {
        return m_sr11.get();
    }

    void sr11(ubyte sr11)
    {
        m_sr11.set(sr11);
    }

    ubyte sr12()
    {
        return m_sr12.get();
    }

    void sr12(ubyte sr12)
    {
        m_sr12.set(sr12);
    }

    ubyte sr13()
    {
        return m_sr13.get();
    }

    void sr13(ubyte sr13)
    {
        m_sr13.set(sr13);
    }

    ubyte sr14()
    {
        return m_sr14.get();
    }

    void sr14(ubyte sr14)
    {
        m_sr14.set(sr14);
    }

    ubyte sr21()
    {
        return m_sr21.get();
    }

    void sr21(ubyte sr21)
    {
        m_sr21.set(sr21);
    }

    ubyte sr22()
    {
        return m_sr22.get();
    }

    void sr22(ubyte sr22)
    {
        m_sr22.set(sr22);
    }

    ubyte sr23()
    {
        return m_sr23.get();
    }

    void sr23(ubyte sr23)
    {
        m_sr23.set(sr23);
    }

    ubyte sr24()
    {
        return m_sr24.get();
    }

    void sr24(ubyte sr24)
    {
        m_sr24.set(sr24);
    }

    ubyte sr30()
    {
        return m_sr30.get();
    }

    void sr30(ubyte sr30)
    {
        m_sr30.set(sr30);
    }

    ubyte sr31()
    {
        return m_sr31.get();
    }

    void sr31(ubyte sr31)
    {
        m_sr31.set(sr31);
    }

    ubyte sr32()
    {
        return m_sr32.get();
    }

    void sr32(ubyte sr32)
    {
        m_sr32.set(sr32);
    }

    ubyte sr33()
    {
        return m_sr33.get();
    }

    void sr33(ubyte sr33)
    {
        m_sr33.set(sr33);
    }

    ubyte sr34()
    {
        return m_sr34.get();
    }

    void sr34(ubyte sr34)
    {
        m_sr34.set(sr34);
    }

    ubyte sr41()
    {
        return m_sr41.get();
    }

    void sr41(ubyte sr41)
    {
        m_sr41.set(sr41);
    }

    ubyte sr42()
    {
        return m_sr42.get();
    }

    void sr42(ubyte sr42)
    {
        m_sr42.set(sr42);
    }

    ubyte sr43()
    {
        return m_sr43.get();
    }

    void sr43(ubyte sr43)
    {
        m_sr43.set(sr43);
    }

    ubyte sr44()
    {
        return m_sr44.get();
    }

    void sr44(ubyte sr44)
    {
        m_sr44.set(sr44);
    }

    ubyte sr50()
    {
        return m_sr50.get();
    }

    void sr50(ubyte sr50)
    {
        m_sr50.set(sr50);
    }

    ubyte sr51()
    {
        return m_sr51.get();
    }

    void sr51(ubyte sr51)
    {
        m_sr51.set(sr51);
    }

    ubyte sr52()
    {
        return m_sr52.get();
    }

    void sr52(ubyte sr52)
    {
        m_sr52.set(sr52);
    }

    ubyte wave(int index)
    {
        return index < m_wave.length ? m_wave[index] : 0xff;
    }

    void wave(int index, ubyte value)
    {
        if (index < m_wave.length)
        {
            m_wave[index] = value;
        }
    }
}
