module gameboy.gpu;

import gameboy.register;

import util.bitmask;
alias bitmask = util.bitmask;

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

immutable int BACKGROUND_WIDTH = 256;
immutable int BACKGROUND_HEIGHT = 256;

class Gpu
{
    private int m_counter;

    private Lcdc m_lcdc;
    private Stat m_stat;

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

    this()
    {
        m_stat.mode = Stat.Mode.OAM_READ;
    }

    ubyte lcdc()
    {
        return m_lcdc.get();
    }

    void lcdc(ubyte lcdc)
    {
        return m_lcdc.set(lcdc);
    }

    ubyte stat()
    {
        return m_stat.get();
    }

    void stat(ubyte stat)
    {
        m_stat.set(stat);
    }

    ubyte scy()
    {
        return m_scrollY;
    }

    void scy(ubyte scy)
    {
        m_scrollY = scy;
    }

    ubyte scx()
    {
        return m_scrollX;
    }

    void scx(ubyte scx)
    {
        m_scrollX = scx;
    }

    ubyte ly()
    {
        return m_currentY;
    }

    void ly(ubyte ly)
    {
        m_currentY = 0;
        checkYCoincidence();
        setMode(Stat.Mode.OAM_READ);
    }

    ubyte lyc()
    {
        return m_compareY;
    }

    void lyc(ubyte lyc)
    {
        m_compareY = lyc;
    }

    ubyte wy()
    {
        return m_windowY;
    }

    void wy(ubyte wy)
    {
        m_windowY = wy;
    }

    ubyte wx()
    {
        return m_windowX;
    }

    void wx(ubyte wx)
    {
        m_windowX = wx;
    }

    ubyte bgp()
    {
        return m_bgPalette;
    }

    void bgp(ubyte palette)
    {
        m_bgPalette = palette;
    }

    ubyte obp0()
    {
        return m_objPaletteData0;
    }

    void obp0(ubyte palette)
    {
        m_objPaletteData0 = palette;
    }

    ubyte obp1()
    {
        return m_objPaletteData1;
    }

    void obp1(ubyte palette)
    {
        m_objPaletteData1 = palette;
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

    @property private ushort bgTileMapAddress() {
        return (m_lcdc.bgTileMap == Lcdc.BgTileMapAddressArea.BTMA_9C00_9FFF ? 0x9C00 : 0x9800) - 0x8000;
    }

    @property private ushort bgTileDataAddress() {
        return ((m_lcdc.bgTileData == Lcdc.BgTileDataAddressArea.BTDAA_8000_8FFF) ? 0x8000 : 0x9000) - 0x8000;
    }

    @property private bool isTileNumberSigned() {
        return m_lcdc.bgTileData == Lcdc.BgTileDataAddressArea.BTDAA_8800_97FF;
    }

    @property private bool bgVisible() {
        return true;     //m_lcdc.bgOn;
    }

    @property private bool spriteVisible() {
        return m_lcdc.spriteOn;
    }

    @property private bool isDisplayOn() {
        return m_lcdc.lcdOn;
    }

    private void setMode(Stat.Mode mode)
    {
        m_stat.mode = mode;

        if ((mode == Stat.Mode.VBLANK && m_stat.intVBlank) ||
            (mode == Stat.Mode.HBLANK && m_stat.intHBlank) ||
            (mode == Stat.Mode.OAM_READ && m_stat.intOAMRead))
        {
            onLcdcStatInterrupt();
        }
    }

    private void checkYCoincidence()
    {
        m_stat.yCoincidence = m_currentY == m_compareY;
        if (m_stat.yCoincidence && m_stat.intYCoincidence)
        {
            onLcdcStatInterrupt();
        }
    }

    private int getTileDataPos(int line, ubyte tileNumber) {
        int pos = (line % TILE_HEIGHT) * 2;

        if (tileNumber < 128 || !isTileNumberSigned())
        {
            pos += tileNumber * TILE_SIZE;
        }
        else
        {
            pos += cast(byte) (tileNumber) * TILE_SIZE;
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

    private void fillScanline(ubyte shadeGroup) {
        int b = m_currentY * SCREEN_BYTES_PER_LINE;
        int e = b + SCREEN_BYTES_PER_LINE;
        m_frame[b .. e] = shadeGroup;
    }

    private void renderScanlineBackground()
    {
        immutable ushort dataAddr = bgTileDataAddress();
        immutable ushort mapAddr  = bgTileMapAddress();

        int screenY = m_currentY;
        int windowY = (screenY + m_scrollY) % BACKGROUND_HEIGHT;

        for (int screenX = 0; screenX < SCREEN_WIDTH; screenX++)
        {
            int windowX = (screenX + m_scrollX) % BACKGROUND_WIDTH;

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

    private void renderScanlineSprites()
    {
        int line = m_currentY;

        int[] sprites = [];
        for (int i = 0; i < 40; i++) {
            int y = m_oam[i * 4];
            if (line >= (y - 16) && line < y) {
                sprites ~= i;
            }
        }

        // TODO: Priority ordering

        // TODO: Sprite render
    }

    private void renderScanline()
    {
        if (m_currentY >= SCREEN_HEIGHT) {
            // out-of-bound
            return;
        }

        if (isDisplayOn())
        {
            if (bgVisible())
            {
                renderScanlineBackground();
            }
            else
            {
                fillScanline(0x00); // blank
            }

            if (spriteVisible())
            {
                renderScanlineSprites();
            }
        }
        else
        {
            fillScanline(0x00); // blank
        }
    }

    void addTicks(ubyte elapsed)
    {
        m_counter += elapsed;

        switch (m_stat.mode) {
            case Stat.Mode.HBLANK:
                if (m_counter >= 204)
                {
                    m_counter -= 204;
                    m_currentY += 1;
                    checkYCoincidence();

                    if (m_currentY >= 143)
                    {
                        setMode(Stat.Mode.VBLANK);
                        onVBlankInterrupt();
                        renderScanline();
                        onFrameReady(m_frame);
                    }
                    else
                    {
                        setMode(Stat.Mode.OAM_READ);
                    }
                }
                break;
            case Stat.Mode.VBLANK:
                if (m_counter >= 456)
                {
                    m_counter -= 456;
                    m_currentY += 1;
                    if (m_currentY > 153) {
                        m_currentY = 0;
                        setMode(Stat.Mode.OAM_READ);
                    }
                    checkYCoincidence();
                }
                break;
            case Stat.Mode.OAM_READ:
                if (m_counter >= 80)
                {
                    m_counter -= 80;
                    setMode(Stat.Mode.TRANSFER);
                }
                break;
            case Stat.Mode.TRANSFER:
                if (m_counter >= 172)
                {
                    m_counter -= 172;
                    setMode(Stat.Mode.HBLANK);
                    renderScanline();
                }
                break;
            default:
                throw new Exception("Illegal GPU State");
        }
    }
}
