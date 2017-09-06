import gpu;
import std.stdio;

// Pass frame buffer fram emulator to gui using triple buffering
class FrameQueue {
    private immutable int BUFFER_COUNT = 3;

    private immutable int lines;
    private immutable int columns;
    private immutable int bpp;

    private immutable int bytesPerLine;
    private immutable int size;

    private shared int reader = 0;
    private shared int writer = 0;

    private ubyte[BUFFER_COUNT][] buffers;

    this(int lines, int columns, int bpp) {
        this.lines = lines;
        this.columns = columns;
        this.bpp = bpp;

        this.bytesPerLine = columns * bpp / 8;
        this.size = lines * columns * bytesPerLine;

        this.buffers = new ubyte[BUFFER_COUNT][size];
    }

    // Write a frame to argument. (Always use the same thread to write)
    bool writeFrame(ref ubyte[][] frame) {
        if (!isFull()) {
            // drop frame, no buffer available
            return false;
        }

        foreach (int l; 0..lines)
        {
            int b = l * bytesPerLine;
            int e = (l + 1) * bytesPerLine;

            // flat 2d buffer to 1d
            buffers[writer][b .. e] = frame[l][0 .. bytesPerLine];
        }

        writer = (writer + 1) % BUFFER_COUNT; // Not thread safe if more than one thread writing
        return true;
    }

    // Read a frame to argument. (Always use the same thread to read)
    bool readFrame(ref ubyte[] frame) {
        if (!isEmpty()) {
            // no frame to available to read
            writeln("FrameQueue FULL");
            return false;
        }

        frame[0 .. size] = buffers[reader][0 .. size];

        reader = (reader + 1) % BUFFER_COUNT; // Not thread safe if more than one thread reading
        return true;
    }

    bool isEmpty() {
        return reader == writer;
    }

    bool isFull() {
        return (reader - 1) == writer || (reader == (BUFFER_COUNT - 1) && writer == 0);
    }
}
