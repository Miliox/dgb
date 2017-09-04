import core.thread;
import derelict.sdl2.sdl;

class FrontEnd
{
    private static immutable int defWidth = 160;
    private static immutable int defHeight = 144;

    private float scale;
    private int width;
    private int height;

    private int lastError;

    private shared bool running;

    this(float scale)
    {
        this.scale = scale;
        this.width = cast(int) (scale * defWidth);
        this.height = cast(int) (scale * defHeight);

        DerelictSDL2.load();
        lastError = SDL_Init(SDL_INIT_VIDEO);
    }

    ~this()
    {
        SDL_Quit();
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

        while (running) {
            SDL_Event event;
            while (SDL_PollEvent(&event)) {
                if (event.type == SDL_QUIT) {
                    running = false;
                    return;
                }
            }
        }

        SDL_DestroyWindow(window);
    }
}
