import core.thread;
import derelict.sdl2.sdl;
import framequeue;

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

    this(float scale)
    {
        this.scale = scale;
        this.width = cast(int) (scale * GB_WIDTH);
        this.height = cast(int) (scale * GB_HEIGHT);

        frameQueue = new FrameQueue(GB_HEIGHT, GB_WIDTH, GB_BPP);

        DerelictSDL2.load();
        lastError = SDL_Init(SDL_INIT_VIDEO);
    }

    ~this()
    {
        SDL_Quit();
    }

    void putFrame(ref ubyte[][] frame)
    {
        frameQueue.writeFrame(frame);
    }

    void decodeFrame(ref Uint32[] dst, ref ubyte[] src)
    {
        // TODO: Convert compact gameboy frame format to SDL2 Surface Bitmap
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

        SDL_Surface* canvas = SDL_GetWindowSurface(window);

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
            }
        }

        SDL_DestroyWindow(window);
    }
}
