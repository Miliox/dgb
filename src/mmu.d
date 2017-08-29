import memory;
import cpu;
import timer;

immutable ubyte[256] bios = [
    0x31, 0xfe, 0xff, 0xaf, 0x21, 0xff, 0x9f, 0x32, 0xcb, 0x7c, 0x20, 0xfb,
    0x21, 0x26, 0xff, 0x0e, 0x11, 0x3e, 0x80, 0x32, 0xe2, 0x0c, 0x3e, 0xf3,
    0xe2, 0x32, 0x3e, 0x77, 0x77, 0x3e, 0xfc, 0xe0, 0x47, 0x11, 0x04, 0x01,
    0x21, 0x10, 0x80, 0x1a, 0xcd, 0x95, 0x00, 0xcd, 0x96, 0x00, 0x13, 0x7b,
    0xfe, 0x34, 0x20, 0xf3, 0x11, 0xd8, 0x00, 0x06, 0x08, 0x1a, 0x13, 0x22,
    0x23, 0x05, 0x20, 0xf9, 0x3e, 0x19, 0xea, 0x10, 0x99, 0x21, 0x2f, 0x99,
    0x0e, 0x0c, 0x3d, 0x28, 0x08, 0x32, 0x0d, 0x20, 0xf9, 0x2e, 0x0f, 0x18,
    0xf3, 0x67, 0x3e, 0x64, 0x57, 0xe0, 0x42, 0x3e, 0x91, 0xe0, 0x40, 0x04,
    0x1e, 0x02, 0x0e, 0x0c, 0xf0, 0x44, 0xfe, 0x90, 0x20, 0xfa, 0x0d, 0x20,
    0xf7, 0x1d, 0x20, 0xf2, 0x0e, 0x13, 0x24, 0x7c, 0x1e, 0x83, 0xfe, 0x62,
    0x28, 0x06, 0x1e, 0xc1, 0xfe, 0x64, 0x20, 0x06, 0x7b, 0xe2, 0x0c, 0x3e,
    0x87, 0xe2, 0xf0, 0x42, 0x90, 0xe0, 0x42, 0x15, 0x20, 0xd2, 0x05, 0x20,
    0x4f, 0x16, 0x20, 0x18, 0xcb, 0x4f, 0x06, 0x04, 0xc5, 0xcb, 0x11, 0x17,
    0xc1, 0xcb, 0x11, 0x17, 0x05, 0x20, 0xf5, 0x22, 0x23, 0x22, 0x23, 0xc9,
    0xce, 0xed, 0x66, 0x66, 0xcc, 0x0d, 0x00, 0x0b, 0x03, 0x73, 0x00, 0x83,
    0x00, 0x0c, 0x00, 0x0d, 0x00, 0x08, 0x11, 0x1f, 0x88, 0x89, 0x00, 0x0e,
    0xdc, 0xcc, 0x6e, 0xe6, 0xdd, 0xdd, 0xd9, 0x99, 0xbb, 0xbb, 0x67, 0x63,
    0x6e, 0x0e, 0xec, 0xcc, 0xdd, 0xdc, 0x99, 0x9f, 0xbb, 0xb9, 0x33, 0x3e,
    0x3c, 0x42, 0xb9, 0xa5, 0xb9, 0xa5, 0x42, 0x3c, 0x21, 0x04, 0x01, 0x11,
    0xa8, 0x00, 0x1a, 0x13, 0xbe, 0x20, 0xfe, 0x23, 0x7d, 0xfe, 0x34, 0x20,
    0xf5, 0x06, 0x19, 0x78, 0x86, 0x23, 0x05, 0x20, 0xfb, 0x86, 0x20, 0xfe,
    0x3e, 0x01, 0xe0, 0x50];

class Mmu : Memory {
    private Cpu m_cpu;
    private Timer m_timer;
    private Memory m_rom;

    private bool m_useBios = true;

    private ubyte[] lram = new ubyte[0x2000];
    private ubyte[] hram = new ubyte[0x7f];

    @property Cpu cpu(Cpu cpu)
    {
        return m_cpu = cpu;
    }

    @property Cpu cpu()
    {
        return cpu;
    }

    @property Timer timer(Timer timer)
    {
        return m_timer = timer;
    }

    @property Timer timer()
    {
        return m_timer;
    }

    @property Memory rom(Memory rom)
    {
        return m_rom = rom;
    }

    @property Memory rom()
    {
        return m_rom;
    }

    ubyte read8(ushort address)
    {
        if (m_useBios && address < bios.length)
        {
            return bios[address];
        }
        else if (address < 0x8000)
        {
            return m_rom.read8(address);
        }
        else if (address >= 0xc000 && address < 0xe000)
        {
            return lram[address - 0xc000];
        }
        else if (address >= 0xe000 && address < 0xfe00)
        {
            return lram[address - 0xe000];
        }
        else if (address >= 0xff80 && address < 0xffff)
        {
            return hram[address - 0xff80];
        }

        switch (address)
        {
            case 0xff04:
                return m_timer.div();
            case 0xff05:
                return m_timer.tima();
            case 0xff06:
                return m_timer.tma();
            case 0xff08:
                return m_timer.tac();
            case 0xff0f:
                return m_cpu.interruptEnable();
            case 0xffff:
                return m_cpu.interruptFlag();
            default:
                return 0;
        }
    }

    void write8(ushort address, ubyte value) {
        if (m_useBios && address < bios.length)
        {
            // read only
            return;
        }
        else if (address < 0x8000)
        {
            m_rom.write8(address, value);
            return;
        }
        else if (address >= 0xc000 && address < 0xe000)
        {
            lram[address - 0xc000] = value;
            return;
        }
        else if (address >= 0xe000 && address < 0xfe00)
        {
            lram[address - 0xe000] = value;
            return;
        }
        else if (address >= 0xff80 && address < 0xffff)
        {
            hram[address - 0xff80] = value;
            return;
        }

        switch (address)
        {
            case 0xff04:
                m_timer.div(value);
                break;
            case 0xff05:
                m_timer.tima(value);
                break;
            case 0xff06:
                m_timer.tma(value);
                break;
            case 0xff08:
                m_timer.tac(value);
                break;
            case 0xff0f:
                m_cpu.interruptEnable(value);
                break;
            case 0xff50:
                if (m_useBios)
                {
                    m_useBios = false;
                }
                break;
            case 0xffff:
                m_cpu.interruptFlag(value);
                break;
            default:
                break;
        }
    }
}
