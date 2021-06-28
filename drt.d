module drt;

extern (C) int main(int argc, char** argv);

extern (C)
{
    int alloco();
    int alloca();
    int allocs(size_t len, immutable(char) * src);
    int allocn(double n);
    int allocf(void function() f);
    int objdup(int obj);
    int loadjs(size_t len, immutable(char) * src);

    void objrm(int ptr);
    void increfc(int ptr);
    void decrefc(int ptr);

    void settmpstr(size_t len, immutable(char) * src);

    void objsetptr(int dest, int src, size_t len, immutable(char) * src);
    void objsetn(int dest, int src, int n);

    int objgetptr(int src, size_t len, immutable(char) * src);
    int objgetn(int src, double n);

    int objgetval(int src);

    int objbind(int src, size_t len, immutable(char) * src);

}

extern (C) void _start()
{
    main(0, null);
}

template objcall(Args...)
{
    template objcallnargs(int n)
    {
        static if (n == 0)
        {
            enum string objcallnargs = "int";
        }
        else
        {
            enum string objcallnargs = objcallnargs!(n - 1) ~ ",int";
        }
    }
    enum string objcallf = "objcall" ~ num2str!(Args.length);
    mixin("pragma(mangle, `" ~ objcallf ~ "`) int " ~ objcallf ~ "(" ~ objcallnargs!(Args.length) ~ ");");
    int objcall(int ptr, Args args)
    {
        return mixin(objcallf)(ptr, args);
    }
}

struct GlobalThis
{
    static Value opIndex(string src)
    {
        int js = loadjs(src.length, src.ptr);
        Value ret = Value.from(js);
        return ret;
    }
}

struct Value
{
align(1):
    int ptr = 0;
    int refc = 0;

    static Value from(int vptr)
    {
        Value ret;
        ret.ptr = vptr;
        return ret;
    }

    Value dup()
    {
        return Value.from(objdup(ptr));
    }

    this(this)
    {
        refc++;
    }

    ~this()
    {
        if (refc == 0)
        {
            objrm(ptr);
        }
        refc--;
    }

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
        ptr = allocs(s.length, s.ptr);
    }

    this(T)(T v) if (is(typeof(*v) == function))
    {
        extern (C) void function() f;
        f = cast(typeof(f)) v;
        ptr = allocf(f);
    }

    this(Value v)
    {
        ptr = v.ptr;
        refc = -1;
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
        return Value.from(objgetptr(ptr, ind.length, ind.ptr));
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
        objsetptr(ptr, other.ptr, index.length, index.ptr);
    }

    Value opCall(Args...)(Args args)
    {
        template objcallargs(int n)
        {
            static if (n == 0)
            {
                enum string objcallargs = "";
            }
            else static if (n == 1)
            {
                enum string objcallargs = "Value(args[0]).ptr";
            }
            else
            {
                enum string objcallargs = objcallargs!(n - 1) ~ ",Value(args[" ~ num2str!(n - 1) ~ "]).ptr";
            }
        }
        int got = mixin("objcall(" ~ objcallargs!(Args.length) ~ ", ptr)");
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
        return Value.from(objbind(ptr, method.length, method.ptr));
    }
}

template num2str(int n)
{
    static if (n < 10)
    {
        enum string num2str = ['0' + n];
    }
    else
    {
        enum string num2str = num2str!(n / 10) ~ cast(char)('0' + (n % 10));
    }
}
