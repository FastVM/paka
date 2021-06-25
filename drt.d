module drt;

extern (C) int main(int argc, char** argv);

extern (C)
{
    double alloc();
    double allocs();
    double allocn(double n);
    double allocf(void function() f);
    double objdup(double obj);
    void objrm(double ptr);
    double loadjs();

    void tmpadd(int c);
    void tmpdel();

    void objsetptr(double dest, double src);
    void objsetn(double dest, double src, double n);

    double objgetptr(double src);
    double objgetn(double src, double n);

    double objgetval(double src);

    double objbind(double src);
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

struct GlobalThis
{
    static Value opIndex(string src)
    {
        Value ret = void;
        setstr(src);
        ret.ptr = loadjs();
        return ret;
    }

    // static Value opDispatch(string member)()
    // {
    //     return GlobalThis[member];
    // }
}

struct Value
{
align(1):
    double ptr;
    // int refc = 1;

    static Value from(double vptr)
    {
        Value ret;
        ret.ptr = objdup(vptr);
        return ret;
    }

    // this(this)
    // {
    //     double last = ptr;
    //     ptr = objdup(last);
    //     objrm(last);
    // }

    // ~this()
    // {
    //     objrm(ptr);
    // }

    this(double n)
    {
        ptr = allocn(n);
    }

    this(long n)
    {
        ptr = allocn(cast(double) n);
    }

    this(string s)
    {
        setstr(s);
        ptr = allocs();
    }

    this(Value other)
    {
        ptr = objdup(other.ptr);
    }

    this(T)(T v) if (is(typeof(*v) == function))
    {
        extern (C) void function() f;
        f = cast(typeof(f)) v;
        ptr = allocf(f);
    }

    Value opBinary(string op)(Value other)
    {
        double lhs = as!double;
        double rhs = other.as!double;
        double res = mixin("lhs" ~ op ~ "rhs");
        Value ret = Value(ptr);
        return ret;
    }

    Arg opBinary(string op, Arg)(Arg rhs) if (!is(Arg == Value))
    {
        Arg lhs = as!Arg;
        Arg res = mixin("lhs" ~ op ~ "rhs");
        return res;
    }

    Value opIndex(string ind)
    {
        setstr(ind);
        return Value.from(objgetptr(ptr));
    }

    Value opIndex(Value v)
    {
        return this[v.as!double];
    }

    Value opIndex(double n)
    {
        return Value.from(objgetn(ptr, n));
    }

    int opCmp(Arg)(Arg rhs) if (!is(Arg == Value))
    {
        Arg lhs = as!Arg;
        if (lhs < rhs)
        {
            return -1;
        }
        if (lhs == rhs)
        {
            return 0;
        }
        return 1;
    }

    int opCmp(Value arg) 
    {
        double lhs = as!double;
        double rhs = arg.as!double;
        if (lhs < rhs)
        {
            return -1;
        }
        if (lhs == rhs)
        {
            return 0;
        }
        return 1;
    }

    void opIndexAssign(Arg)(Arg arg, Value index)
    {
        Value other = Value(arg);
        objsetn(ptr, other.ptr, index.as!double);
    }

    void opIndexAssign(Arg)(Arg arg, double index)
    {
        Value other = Value(arg);
        objsetn(ptr, other.ptr, index);
    }

    void opIndexAssign(Arg)(Arg arg, string index)
    {
        Value other = Value(arg);
        setstr(index);
        objsetptr(ptr, other.ptr);
    }

    Value opCall(Args...)(Args args)
    {
        Value[args.length] vals;
        static foreach (index; 1 .. args.length + 1)
        {
            vals[index - 1] = Value(args[$ - index]);
            objcallarg(vals[index - 1].ptr);
        }
        double got = objcall(ptr);
        return Value.from(got);
    }

    double as(T : double)()
    {
        return objgetval(this.ptr);
    }

    long as(T : long)()
    {
        return cast(long) as!double;
    }

    Value opBind(string method)
    {
        setstr(method);
        return Value.from(objbind(ptr));
    }

    // Value opDispatch(string member)()
    // {
    //     return this[member];
    // }

    // Value opDispatch(string member, Args...)(Args args)
    // {
    //     return this[member](args);
    // }
}

// void write(string src)
// {
//     foreach (chr; src)
//     {
//         putchar(chr);
//     }
// }

// void write(long src)
// {
//     if (src >= 10)
//     {
//         write(src / 10);
//     }
//     putchar(cast(char)('0' + src % 10));
// }

// void write(double src)
// {
//     if (src < 0)
//     {
//         putchar('-');
//         src *= -1;
//     }
//     ulong d = cast(ulong) src;
//     write(d);
//     putchar('.');
//     foreach (p; 0 .. 16)
//     {
//         src -= d;
//         if (src <= 0.001)
//         {
//             if (p == 0)
//             {
//                 putchar('0');
//             }
//             break;
//         }
//         if (src >= 0.999)
//         {
//             if (p == 0)
//             {
//                 putchar('0');
//             }
//             break;
//         }
//         src *= 10;
//         d = cast(ulong) src;
//         putchar(cast(char)('0' + d));
//     }
// }
