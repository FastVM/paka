module drt;

extern (C) int putchar(int code);
extern(C) void main();

extern(C) void _start()
{
    main();
}

pragma(mangle, "rt.write(Text)") void write(string src)
{
    foreach (chr; src)
    {
        putchar(chr);
    }
}

pragma(mangle, "rt.write(Int)") void write(long src)
{
    if (src >= 10)
    {
        write(src / 10);
    }
    putchar(cast(char)('0' + src % 10));
}

pragma(mangle, "rt.write(Float)") void write(double src)
{
    long nsrc = cast(long) src;
    write(nsrc);
    putchar('.');
    double ddec = src - cast(double) nsrc;
    long dsrc = cast(long)(ddec * 10 ^^ 6);
    write(dsrc);
}
