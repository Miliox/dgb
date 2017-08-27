import memory;
import cpu;

class Timer {
    private static immutable short[4] TIMER_RATIO = [1024, 16, 64, 256];
    private static immutable short  DIVIDER_RATIO = 256;

    private static immutable ubyte TAC_START = 0x04;
    private static immutable ubyte TAC_RATIO = 0x03;

    private ubyte m_divider = 0; // DIV
    private ubyte m_counter = 0; // TIMA
    private ubyte m_modulo  = 0; // TMA
    private ubyte m_control = 0; // TAC

    private short m_dividerFraction;
    private short m_counterFraction;

    void delegate() onInterrupt;

    @property ubyte div()
    {
        return m_divider;
    }

    @property ubyte div(ubyte)
    {
        return m_divider = 0;
    }

    @property ubyte tima()
    {
        return m_counter;
    }

    @property ubyte tima(ubyte tima) {
        return m_counter = tima;
    }

    @property ubyte tma()
    {
        return m_modulo;
    }

    @property ubyte tma(ubyte tma) {
        return m_modulo = tma;
    }

    @property ubyte tac()
    {
        return m_control;
    }

    @property ubyte tac(ubyte tac) {
        return m_control = tac;
    }

    void addTicks(ubyte elapsed)
    {
        m_dividerFraction += elapsed;
        if (m_dividerFraction >= DIVIDER_RATIO)
        {
            m_divider += m_dividerFraction / DIVIDER_RATIO;
            m_dividerFraction %= DIVIDER_RATIO;
        }

        if ((m_control & TAC_START) != 0)
        {
            short period = TIMER_RATIO[m_control & TAC_RATIO];

            short rem = cast(short)(period - m_counterFraction);
            if (rem > elapsed)
            {
                m_counterFraction += elapsed;
            }
            else
            {
                m_counterFraction = rem;
                if (m_counter < 255)
                {
                    m_counter += 1;
                }
                else
                {
                    onInterrupt();
                    m_counter = m_modulo;
                }
            }
        }
    }
}

unittest
{
    Timer t = new Timer();
    t.tac(0x00);
    t.addTicks(128);
    t.addTicks(128);
    assert(t.div() == 1);

    t.tac(0x5);
    t.addTicks(16);
    assert(t.tima() == 1);

    t.tac(0x6);
    t.addTicks(64);
    assert(t.tima() == 2);
}
