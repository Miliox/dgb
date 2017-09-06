import core.thread;
import derelict.sdl2.sdl;
import framequeue;
import std.stdio;

class Gui
{
    private static immutable int GB_WIDTH  = 160;
    private static immutable int GB_HEIGHT = 144;
    private static immutable int GB_BPP = 2;

    private float scale;
    private int width;
    private int height;

    private int lastError;

    private shared bool running;

    private FrameQueue frameQueue;
    private Uint32[4] shades;

    this(float scale)
    {
        this.scale = scale;
        this.width = cast(int) (scale * GB_WIDTH);
        this.height = cast(int) (scale * GB_HEIGHT);

        frameQueue = new FrameQueue(GB_HEIGHT, GB_WIDTH, GB_BPP);
        shades = [0xFF9BBC0F, 0xFF8BAC0F, 0xFF306230, 0xFF0f380f];

        DerelictSDL2.load();
        lastError = SDL_Init(SDL_INIT_VIDEO);
    }

    ~this()
    {
        SDL_Quit();
    }

    void putFrame(ref ubyte[] frame)
    {
        frameQueue.writeFrame(frame);
    }

    void decodeFrame(ref Uint32[] dst, ref ubyte[] src)
    {
        // Convert compact gameboy frame format to SDL2 Surface Bitmap
        for (int i = 0; i < src.length; i++) {
            int px = i * 4;
            dst[px + 0] = shades[(src[i] >> 6) & 0x3];
            dst[px + 1] = shades[(src[i] >> 4) & 0x3];
            dst[px + 2] = shades[(src[i] >> 2) & 0x3];
            dst[px + 3] = shades[src[i] & 0x3];
        }
    }

    void drawTexture(SDL_Texture* texture, ref Uint32[] frameBuffer) {
        int pitch = 0;
        Uint32* pixels = null;
        int ret1 = SDL_LockTexture(texture, null, cast(void**) &pixels, &pitch);
        if (ret1 == 0) {
            pixels[0 .. frameBuffer.length] = frameBuffer[0 .. frameBuffer.length];
            SDL_UnlockTexture(texture);
        } else {
            writefln("Could not lock texture: %s", SDL_GetError());
        }
    }

    void renderTexture(SDL_Renderer* renderer, SDL_Texture* texture) {
        int ret = SDL_RenderClear(renderer);
        if (ret != 0) {
            writefln("Could not clear render: %s", SDL_GetError());
        }

        ret = SDL_RenderCopy(renderer, texture, null, null);
        if (ret != 0) {
            writefln("Could not copy to render: %s", SDL_GetError());
        }

        SDL_RenderPresent(renderer);
    }

    void stop() {
        running = false;
        SDL_Event quit;
        quit.type = SDL_QUIT;
        SDL_PushEvent(&quit);
    }

    void run()
    {
        running = true;
        SDL_Window* window = SDL_CreateWindow("D GameBoy",
            SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, width, height, SDL_WINDOW_SHOWN);
        if (window == null) {
            writefln("Could not create window: %s", SDL_GetError());
        }

        SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
        if (renderer == null) {
            writefln("Could not create renderer: %s", SDL_GetError());
        }

        SDL_Texture* texture = SDL_CreateTexture(renderer,
            SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING,
            GB_WIDTH, GB_HEIGHT);
        if (texture == null) {
            writefln("Could not create texture: %s", SDL_GetError());
        }

        ubyte[] gbBuffer = new ubyte[GB_WIDTH * GB_HEIGHT * GB_BPP / 8];
        Uint32[] frameBuffer = new Uint32[GB_WIDTH * GB_HEIGHT];

        while (running) {
            SDL_Event event;
            while (SDL_PollEvent(&event)) {
                if (event.type == SDL_QUIT) {
                    running = false;
                    return;
                }
            }

            if (!frameQueue.isEmpty()) {
                frameQueue.readFrame(gbBuffer);
                decodeFrame(frameBuffer, gbBuffer);
                drawTexture(texture, frameBuffer);
                renderTexture(renderer, texture);
            }

            Thread.sleep(dur!("msecs")(5));
        }

        SDL_DestroyTexture(texture);
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
    }
}
