import bitmask;

immutable int SCREEN_WIDTH = 160;
immutable int SCREEN_HEIGHT = 144;

immutable int SCREEN_BPP = 2;               // bits per pixel
immutable int SCREEN_PPB = 8 / SCREEN_BPP;  // pixels per byte
immutable int SCREEN_BYTES_PER_LINE = SCREEN_WIDTH / SCREEN_PPB;

immutable int TILE_SIZE = 16;
immutable int TILE_LINE_SIZE = 2;
immutable int TILE_HEIGHT = 8;
immutable int TILE_WIDTH = 8;

immutable int TILES_PER_LINE = 32;
immutable int TILES_PER_COLUMN = 32;

class Gpu
{
    private int m_counter;

    private ubyte m_lcdc;
    private ubyte m_stat;
    private ubyte m_scrollY;
    private ubyte m_scrollX;
    private ubyte m_currentY;
    private ubyte m_compareY;
    private ubyte m_windowX;
    private ubyte m_windowY;
    private ubyte m_bgPalette;
    private ubyte m_objPaletteData0;
    private ubyte m_objPaletteData1;

    private ubyte[] m_oam = new byte[0xa0];
    private ubyte[] m_ram = new byte[0x2000];

    private ubyte[] m_frame = new byte[SCREEN_HEIGHT * SCREEN_BYTES_PER_LINE];

    void delegate() onVBlankInterrupt;
    void delegate() onLcdcStatInterrupt;
    void delegate(ref ubyte[] frame) onFrameReady;

    private enum Lcdc : ubyte
    {
        LCD_ENABLE      = 1 << 7,
        WIN_TILE_SELECT = 1 << 6,
        WIN_ENABLE      = 1 << 5,
        BG_DATA_SELECT  = 1 << 4,
        BG_TILE_SELECT  = 1 << 3,
        OBJ_SIZE        = 1 << 2,
        OBJ_ENABLE      = 1 << 1,
        BG_DISPLAY      = 1 << 0
    }

    private enum Stat : ubyte
    {
        COINCIDENCE_INTERRUPT = 1 << 6,
        OAM_INTERRUPT         = 1 << 5,
        VBLANK_INTERRUPT      = 1 << 4,
        HBLANK_INTERRUPT      = 1 << 3,
        COINCIDENCE_FLAG      = 1 << 2, // read-only
        MODE_FLAG             = 0x3     // read-only
    }

    private enum Mode : ubyte
    {
        HBLANK = 0,
        VBLANK = 1,
        OAM_READ = 2,
        TRANSFER = 3
    }

    this()
    {
        m_stat = Mode.OAM_READ;
    }

    @property ubyte lcdc()
    {
        return m_lcdc;
    }

    @property ubyte lcdc(ubyte lcdc)
    {
        return m_lcdc = lcdc;
    }

    @property ubyte stat()
    {
        return m_stat;
    }

    @property ubyte stat(ubyte stat)
    {
        return m_stat = (stat & ~Stat.MODE_FLAG) | (m_stat & Stat.MODE_FLAG);
    }

    @property ubyte scy()
    {
        return m_scrollY;
    }

    @property ubyte scy(ubyte scy)
    {
        return m_scrollY = scy;
    }

    @property ubyte scx()
    {
        return m_scrollX;
    }

    @property ubyte scx(ubyte scx)
    {
        return m_scrollX = scx;
    }

    @property ubyte ly()
    {
        return m_currentY;
    }

    @property ubyte ly(ubyte ly)
    {
        m_currentY = 0;
        checkYCoincidence();
        setMode(Mode.OAM_READ);
        return m_currentY;
    }

    @property ubyte lyc()
    {
        return m_compareY;
    }

    @property ubyte lyc(ubyte lyc)
    {
        return m_compareY = lyc;
    }

    @property ubyte wy()
    {
        return m_windowY;
    }

    @property ubyte wy(ubyte wy)
    {
        return m_windowY = wy;
    }

    @property ubyte wx()
    {
        return m_windowX;
    }

    @property ubyte wx(ubyte wx)
    {
        return m_windowX = wx;
    }

    @property ubyte bgp()
    {
        return m_bgPalette;
    }

    @property ubyte bgp(ubyte palette)
    {
        return m_bgPalette = palette;
    }

    @property ubyte obp0()
    {
        return m_objPaletteData0;
    }

    @property ubyte obp0(ubyte palette)
    {
        return m_objPaletteData0 = palette;
    }

    @property ubyte obp1()
    {
        return m_objPaletteData1;
    }

    @property ubyte obp1(ubyte palette)
    {
        return m_objPaletteData1 = palette;
    }

    @property ubyte oam(ushort position)
    {
        return position < m_oam.length ? m_oam[position] : 0;
    }

    @property void oam(ushort position, ubyte value)
    {
        if (position < m_oam.length)
        {
            m_oam[position] = value;
        }
    }

    @property ubyte ram(ushort position)
    {
        return position < m_ram.length ? m_ram[position] : 0;
    }

    @property void ram(ushort position, ubyte value)
    {
        if (position < m_ram.length)
        {
            m_ram[position] = value;
        }
    }

    @property private ushort bgTileMapPosition() {
        return (bitmask.check(m_lcdc, Lcdc.BG_TILE_SELECT) ? 0x9C00 : 0x9800) - 0x8000;
    }

    @property private ushort bgTileDataPosition() {
        return (bitmask.check(m_lcdc, Lcdc.BG_DATA_SELECT) ? 0x8000 : 0x9000) - 0x8000;
    }

    @property private bool isTileNumberSigned() {
        return !bitmask.check(m_lcdc, Lcdc.BG_DATA_SELECT);
    }

    @property private bool bgVisible() {
        return bitmask.check(m_lcdc, Lcdc.BG_DISPLAY);
    }

    private void setMode(Mode mode)
    {
        m_stat = (m_stat & ~Stat.MODE_FLAG) | (mode & Stat.MODE_FLAG);

        if (((m_stat & Stat.MODE_FLAG) == Mode.VBLANK && (m_stat & Stat.VBLANK_INTERRUPT) != 0) ||
            ((m_stat & Stat.MODE_FLAG) == Mode.HBLANK && (m_stat & Stat.HBLANK_INTERRUPT) != 0) ||
            ((m_stat & Stat.MODE_FLAG) == Mode.OAM_READ && (m_stat & Stat.OAM_INTERRUPT) != 0))
        {
            onLcdcStatInterrupt();
        }
    }

    private void checkYCoincidence()
    {
        if (m_currentY == m_compareY)
        {
            m_stat |= Stat.COINCIDENCE_FLAG;

            if ((m_stat & Stat.COINCIDENCE_INTERRUPT) != 0)
            {
                onLcdcStatInterrupt();
            }
        }
        else
        {
            m_stat &= ~Stat.COINCIDENCE_FLAG;
        }
    }

    private int getTileDataPos(int line, ubyte tileNumber) {
        int pos = (line % TILE_HEIGHT) * 2;

        if (tileNumber < 128 && !isTileNumberSigned())
        {
            pos += tileNumber * TILE_SIZE;
        }
        else
        {
            pos += byte(tileNumber) * TILE_SIZE;
        }

        return pos;
    }

    private void writeShade(int x, int y, int shadeIndex) {
        immutable ubyte[] mask  = [0xc0, 0x30, 0x0c, 0x03];

        ubyte shade = m_bgPalette >> (shadeIndex * 2);
        shade &= 0x3;

        int subIdx = x % SCREEN_PPB;
        int shift = (8 - SCREEN_BPP) - (subIdx * SCREEN_BPP);
        int pos = (x / SCREEN_PPB)  + (y * SCREEN_BYTES_PER_LINE);

        ubyte shadeGroup = m_frame[pos];
        shadeGroup &= ~mask[subIdx];
        shadeGroup |= mask[subIdx] & (shade << shift);
        m_frame[pos] = shadeGroup;
    }

    private void renderScanline() {
        if (m_currentY >= SCREEN_HEIGHT) {
            // out-of-bound
            return;
        }

        immutable ushort dataAddr = bgTileDataPosition();
        immutable ushort mapAddr  = bgTileMapPosition();

        int screenY = m_currentY;
        int windowY = (screenY + m_scrollY) % 256;

        for (int screenX = 0; screenX < SCREEN_WIDTH; screenX++)
        {
            int windowX = (screenX + m_scrollX) % 256;

            int winTileIndex = (windowX / TILE_WIDTH) + ((windowY / TILE_HEIGHT) * TILES_PER_LINE);

            ubyte tileIndex = m_ram[mapAddr + winTileIndex];

            int tileDataAddr = dataAddr + getTileDataPos(windowY, tileIndex);

            ubyte tileLsb = m_ram[tileDataAddr];
            ubyte tileMsb = m_ram[tileDataAddr + 1];

            ubyte bitIndex = 7 - (screenX % 8);

            ubyte shadeIndex = 0;
            shadeIndex += ((tileLsb >> bitIndex) & 1) ? 2 : 0;
            shadeIndex += ((tileMsb >> bitIndex) & 1) ? 1 : 0;

            writeShade(screenX, screenY, shadeIndex);
        }
    }

    void addTicks(ubyte elapsed)
    {
        m_counter += elapsed;

        Mode m = cast(Mode) (m_stat & Stat.MODE_FLAG);
        switch (m) {
            case Mode.HBLANK:
                if (m_counter >= 204)
                {
                    m_counter -= 204;
                    m_currentY += 1;
                    checkYCoincidence();

                    if (m_currentY >= 143)
                    {
                        setMode(Mode.VBLANK);
                        onVBlankInterrupt();
                        renderScanline();
                        onFrameReady(m_frame);
                    }
                    else
                    {
                        setMode(Mode.OAM_READ);
                    }
                }
                break;
            case Mode.VBLANK:
                if (m_counter >= 456)
                {
                    m_counter -= 456;
                    m_currentY += 1;
                    if (m_currentY > 153) {
                        m_currentY = 0;
                        setMode(Mode.OAM_READ);
                    }
                    checkYCoincidence();
                }
                break;
            case Mode.OAM_READ:
                if (m_counter >= 80)
                {
                    m_counter -= 80;
                    setMode(Mode.TRANSFER);
                }
                break;
            case Mode.TRANSFER:
                if (m_counter >= 172)
                {
                    m_counter -= 172;
                    setMode(Mode.HBLANK);
                    renderScanline();
                }
                break;
            default:
                throw new Exception("Illegal GPU State");
        }
    }
}
