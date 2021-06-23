module drt;

extern (C) int main(int argc, char** argv);

extern (C)
{
    int putchar(int code);

    double alloc();
    double allocs();
    double allocn(double n);
    double loadjs();

    void tmpadd(int c);
    void tmpdel();

    void objsetptr(double dest, double src);
    double objgetptr(double src);

    double objgetval(double src);

    double objcall(double src);
    void objcallarg(double arg);
}

extern (C) void _start()
{
    main(0, null);
}

void setstr(string str)
{
    tmpdel();
    foreach (c; str)
    {
        tmpadd(c);
    }
}

struct GlobalThis {
    static Value opIndex(string src) {
        Value ret = void;
        setstr(src);
        ret.ptr = loadjs();
        return ret;
    } 

    static Value opDispatch(string member)()
    {
        return GlobalThis[member];
    }
}

struct Value {
    double ptr;

    static Value from(double vptr)
    {
        Value ret = void;
        ret.ptr = vptr;
        return ret;
    }

    this(double n) {
        ptr = allocn(n);
    }

    this(string s) {
        setstr(s);
        ptr = allocs();
    }

    this(Value other) {
        ptr = other.ptr;
    }

    Value opIndex(string ind)
    {
        setstr(ind);
        return Value.from(objgetptr(ptr));
    }

    void opIndexAssign(Arg)(Arg arg, string index)
    {
        Value other = Value(arg);
        setstr(index);
        objsetptr(ptr, other.ptr);
    }

    Value opCall(Args...)(Args args)
    {
        static foreach (index; 1..args.length+1)
        {
            objcallarg(Value(args[$-index]).ptr);
        }
        double got = objcall(ptr);
        return Value.from(got);
    }

    double as(T: double)()
    {
        return objgetval(this.ptr);
    }

    Value opDispatch(string member)()
    {
        return this[member];
    }

    Value opDispatch(string member, Args...)(Args args)
    {
        return this[member](args);
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
    if (src < 0)
    {
        putchar('-');
        src *= -1;
    }
    ulong d = cast(ulong) src;
    write(d);
    putchar('.');
    foreach (p; 0 .. 16)
    {
        src -= d;
        if (src <= 0.001)
        {
            if (p == 0)
            {
                putchar('0');
            }
            break;
        }
        if (src >= 0.999)
        {
            if (p == 0)
            {
                putchar('0');
            }
            break;
        }
        src *= 10;
        d = cast(ulong) src;
        putchar(cast(char)('0' + d));
    }
}
