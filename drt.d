module drt;

extern (C) int putchar(int code);
extern(C) int main(int argc, char** argv);

version(WebAssembly) {
    extern(C) void _start()
    {
        main(0, null);
    }
}

void write(string src)
{
    foreach (chr; src)
    {
        putchar(chr);
    }
}

void write(long src)
{
    if (src >= 10)
    {
        write(src / 10);
    }
    putchar(cast(char)('0' + src % 10));
}

void write(double src)
{
    if (src<0)
    {
        putchar('-');
        src *= -1;
    }
    ulong d = cast(ulong) src;
    write(d);
    putchar('.');
    foreach (p; 0..16)
    {
        src -= d;
        if (src <= 0.001) {
            if (p == 0) {
                putchar('0');
            }
            break;
        }
        if (src >= 0.999) {
            if (p == 0) {
                putchar('0');
            }
            break;
        }
        src *= 10;
        d = cast(ulong) src;
        putchar(cast(char)('0'+d));
    }
}
