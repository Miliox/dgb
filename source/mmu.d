import memory;
import cpu;
import gpu;
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
    private Gpu m_gpu;
    private Timer m_timer;
    private Memory m_rom;

    private bool m_useBios = true;

    private bool   m_dmaOn = false;
    private ubyte  m_dmaIndex = 0;
    private ushort m_dmaBaseAddress = 0;

    private ubyte[] m_lram = new ubyte[0x2000];
    private ubyte[] m_hram = new ubyte[0x7f];

    @property Cpu cpu(Cpu cpu)
    {
        return m_cpu = cpu;
    }

    @property Cpu cpu()
    {
        return m_cpu;
    }

    @property Gpu gpu(Gpu gpu)
    {
        return m_gpu = gpu;
    }

    @property Gpu gpu()
    {
        return m_gpu;
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

    void addTicks(ubyte elapsed) {
        while (m_dmaOn && elapsed > 0)
        {
            if (m_dmaIndex < 0xa0)
            {
                // transfer will take 640 cycles (GB takes 671 ~160usec)
                ushort addr = cast(ushort) (m_dmaBaseAddress + m_dmaIndex);
                m_gpu.oam(m_dmaIndex, read8(addr));
                m_dmaIndex += 1;
            }
            else {
                m_dmaOn = false;
            }
            elapsed -= 4; // elapsed cpu cycles always multiple of 4, so no checks for underflown
        }

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
        else if (address < 0xa000)
        {
            return m_gpu.ram(cast(ushort)(address - 0x8000));
        }
        else if (address >= 0xc000 && address < 0xe000)
        {
            return m_lram[address - 0xc000];
        }
        else if (address >= 0xe000 && address < 0xfe00)
        {
            return m_lram[address - 0xe000];
        }
        else if (address < 0xfea0)
        {
            return m_gpu.oam(cast(ushort) (address - 0xfe00));
        }
        else if (address >= 0xff80 && address < 0xffff)
        {
            return m_hram[address - 0xff80];
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
            case 0xff40:
                return m_gpu.lcdc();
            case 0xff41:
                return m_gpu.stat();
            case 0xff42:
                return m_gpu.scy();
            case 0xff43:
                return m_gpu.scx();
            case 0xff44:
                return m_gpu.ly();
            case 0xff45:
                return m_gpu.lyc();
            case 0xff46:
                return 0;
            case 0xff47:
                return m_gpu.bgp();
            case 0xff48:
                return m_gpu.obp0();
            case 0xff49:
                return m_gpu.obp1();
            case 0xff4a:
                return m_gpu.wy();
            case 0xff4b:
                return m_gpu.wx();
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
        else if (address < 0xa000)
        {
            m_gpu.ram(cast(ushort) (address - 0x8000), value);
            return;
        }
        else if (address >= 0xc000 && address < 0xe000)
        {
            m_lram[address - 0xc000] = value;
            return;
        }
        else if (address >= 0xe000 && address < 0xfe00)
        {
            m_lram[address - 0xe000] = value;
            return;
        }
        else if (address < 0xfea0)
        {
            m_gpu.oam(cast (ushort) (address - 0xfe00), value);
            return;
        }
        else if (address >= 0xff80 && address < 0xffff)
        {
            m_hram[address - 0xff80] = value;
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
            case 0xff40:
                m_gpu.lcdc(value);
                break;
            case 0xff41:
                m_gpu.stat(value);
                break;
            case 0xff42:
                m_gpu.scy(value);
                break;
            case 0xff43:
                m_gpu.scx(value);
                break;
            case 0xff44:
                m_gpu.ly(value);
                break;
            case 0xff45:
                m_gpu.lyc(value);
                break;
            case 0xff46:
                if (value <= 0xf1) {
                    m_dmaOn = true;
                    m_dmaIndex = 0;
                    m_dmaBaseAddress = (value << 8);
                }
                break;
            case 0xff47:
                m_gpu.bgp(value);
                break;
            case 0xff48:
                m_gpu.obp0(value);
                break;
            case 0xff49:
                m_gpu.obp1(value);
                break;
            case 0xff4a:
                m_gpu.wy(value);
                break;
            case 0xff4b:
                m_gpu.wx(value);
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
