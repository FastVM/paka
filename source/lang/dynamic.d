module lang.dynamic;

import std.algorithm;
import std.conv;
import std.format;
import std.functional;
import std.math;
import std.traits;
import std.typecons;
import std.array;
import std.stdio;
import core.memory;
import lang.bytecode;
import lang.vm;
import lang.error;
import lang.number;
import lang.data.rope;
import lang.data.mpfr;
import lang.data.map;
public import lang.number;

version = safe;

alias Args = Dynamic[];
alias Array = Dynamic[];

alias Mapping = Map!(Dynamic, Dynamic);
Mapping emptyMapping()
{
    return new Mapping;
}

// size_t hashed = 0;
// alias Mapping = Dynamic[Dynamic];
// Mapping emptyMapping(){
//     return Mapping.init;
// }

class Table
{
    // Map!(Dynamic, Dynamic) table;
    Mapping table = emptyMapping;
    alias table this;

    Table init()
    {
        return Table.empty;
    }

    static Table empty()
    {
        return new Table;
    }

    this()
    {
    }

    this(typeof(table) t)
    {
        table = t;
    }

    int opApply(int delegate(Dynamic, Dynamic) dg)
    {
        foreach (Dynamic a, Dynamic b; table)
        {
            if (int res = dg(a, b))
            {
                return res;
            }
        }
        return 0;
    }

    Dynamic rawIndex(Dynamic key)
    {
        if (Dynamic* d = key in table)
        {
            return *d;
        }
        throw new BoundsException("key not found: " ~ key.to!string);
    }

    void set(Dynamic key, Dynamic value)
    {
        table[key] = value;
    }

    Dynamic opIndex(Dynamic key)
    {
        Dynamic* val = key in this;
        if (val !is null)
        {
            return *val;
        }
        throw new TypeException("table item not found: " ~ key.to!string);
    }

    override string toString()
    {
        return table.to!string;
    }
}

Dynamic dynamicZero;

static this()
{
    dynamicZero = dynamic(0);
}

bool fastMathNotEnabled = false;

Dynamic dynamic(T...)(T a)
{
    return Dynamic(a);
}

struct Dynamic
{
    enum Type : byte
    {
        nil,
        log,
        sml,
        big,
        str,
        arr,
        tab,
        fun,
        del,
        pro,
        end,
        pac,
    }

    union Value
    {
        bool log;
        SmallNumber sml;
        BigNumber* bnm;
        string* str;
        Array* arr;
        Table tab;
        union Callable
        {
            void function(Cont, Args) fun;
            void delegate(Cont, Args)* del;
            Function pro;
        }

        Callable fun;
    }

align(8):
    Value value = void;
    Type type = Type.nil;

    static Dynamic strToNum(string s)
    {
        BigNumber big = BigNumber(s);
        if (big.fits && !fastMathNotEnabled)
        {
            return dynamic(SmallNumber(mpfr_get_d(big, mpfr_rnd_t.MPFR_RNDN)));
        }
        return dynamic(big);
    }

    this(Type t)
    {
        type = t;
    }

    this(bool log)
    {
        value.log = log;
        type = Type.log;
    }

    this(SmallNumber num)
    {
        value.sml = num;
        type = Type.sml;
    }

    this(BigNumber num)
    {
        value.bnm = new BigNumber(num);
        type = Type.big;
    }

    this(string str)
    {
        value.str = [str].ptr;
        type = Type.str;
    }

    this(Array arr)
    {
        value.arr = [arr].ptr;
        type = Type.arr;
    }

    this(Mapping tab)
    {
        value.tab = new Table(tab);
        type = Type.tab;
    }

    this(Table tab)
    {
        value.tab = tab;
        type = Type.tab;
    }

    this(void function(Cont, Args) fun)
    {
        value.fun.fun = fun;
        type = Type.fun;
    }

    this(void delegate(Cont, Args) del)
    {
        value.fun.del = [del].ptr;
        type = Type.del;
    }

    this(Function pro)
    {
        value.fun.pro = pro;
        type = Type.pro;
    }

    this(Dynamic other)
    {
        value = other.value;
        type = other.type;
    }

    static Dynamic nil()
    {
        Dynamic ret = dynamic(false);
        ret.value = Dynamic.Value.init;
        ret.type = Dynamic.Type.nil;
        return ret;
    }

    // size_t toHash() const nothrow
    // {
    //     hashed++;
    //     scope(exit)
    //     {
    //         hashed--;
    //     }
    //     if (hashed == 8) {
    //         return 0;
    //     }
    //     final switch (type)
    //     {
    //     case Type.nil:
    //         return 2;
    //     case Type.log:
    //         return cast(size_t) (value.log + 1);
    //     case Type.sml:
    //         return *cast(size_t*)&value.sml;
    //     case Type.big:
    //         return hashOf(value.bnm);
    //     case Type.str:
    //         return hashOf(*value.str);
    //     case Type.arr:
    //         return hashOf(*value.arr);
    //     case Type.tab:
    //         return hashOf(value.tab);
    //     case Type.fun:
    //         return hashOf(value.fun.fun);
    //     case Type.del:
    //         return hashOf(value.fun.del);
    //     case Type.pro:
    //         return hashOf(value.fun.pro);
    //     case Type.end:
    //         assert(0);
    //     case Type.pac:
    //         assert(0);
    //     }
    // }

    string toString()
    {
        return this.strFormat;
    }

    void opCall(Cont cont, Dynamic[] args)
    {
        switch (type)
        {
        case Dynamic.Type.fun:
            fun.fun(cont, args);
            return;
        case Dynamic.Type.del:
            (*fun.del)(cont, args);
            return;
        case Dynamic.Type.pro:
            if (fun.pro.self.length == 0)
            {
                run(cont, fun.pro, args);
                return;
            }
            else
            {
                run(cont, fun.pro, fun.pro.self ~ args);
                return;
            }
        default:
            throw new TypeException("error: not a function: " ~ this.to!string);
        }
    }

    int opCmp(Dynamic other)
    {
        return cmpDynamic(this, other);
    }

    int flatOpCmp(Dynamic other)
    {
        Type t = type;
        switch (t)
        {
        default:
            // assert(0);
            throw new TypeException(
                    "error: not comparable: " ~ this.to!string ~ " " ~ other.to!string);
        case Type.nil:
            return 0;
        case Type.log:
            return value.log - other.log;
        case Type.sml:
            if (other.type == Type.big)
            {
                return value.sml.asBig.opCmp(*other.value.bnm);
            }
            SmallNumber a = value.sml;
            SmallNumber b = other.value.sml;
            if (a < b)
            {
                return -1;
            }
            if (a == b)
            {
                return 0;
            }
            return 1;
        case Type.big:
            if (other.type == Type.sml)
            {
                return (*value.bnm).opCmp(other.value.sml.asBig);
            }
            return (*value.bnm).opCmp(*other.value.bnm);
        case Type.str:
            return cmp(*value.str, other.str);
        }
    }

    bool opEquals(const Dynamic other) const
    {
        return cmpDynamic(this, other) == 0;
    }

    Dynamic opBinary(string op)(Dynamic other)
    {
        if (type == Type.sml)
        {
            if (other.type == Type.sml)
            {
                SmallNumber res = mixin("value.sml " ~ op ~ " other.value.sml");
                if (res.fits)
                {
                    return dynamic(res);
                }
                else
                {
                    return dynamic(mixin("value.sml.asBig " ~ op ~ " other.value.sml.asBig"));
                }
            }
            else if (other.type == Type.big)
            {
                return dynamic(mixin("value.sml.asBig " ~ op ~ "  *other.value.bnm"));
            }
        }
        else if (type == Type.big)
        {
            if (other.type == Type.sml)
            {
                return dynamic(mixin("*value.bnm " ~ op ~ " other.value.sml.asBig"));
            }
            else if (other.type == Type.big)
            {
                return dynamic(mixin("*value.bnm " ~ op ~ " *other.value.bnm"));
            }
        }
        static if (op == "~" || op == "+")
        {
            if (type == Type.str && other.type == Type.str)
            {
                return dynamic(str ~ other.str);
            }
            if (type == Type.arr && other.type == Type.arr)
            {
                return dynamic(arr ~ other.arr);
            }
        }
        static if (op == "*")
        {
            if (type == Type.str && other.type == Type.sml)
            {
                string ret;
                foreach (i; 0 .. other.value.sml)
                {
                    ret ~= str;
                }
                return dynamic(ret);
            }
            if (type == Type.str && other.type == Type.big)
            {
                string ret;
                foreach (i; 0 .. other.as!size_t)
                {
                    ret ~= str;
                }
                return dynamic(ret);
            }
            if (type == Type.arr && other.type == Type.sml)
            {
                Dynamic[] ret;
                foreach (i; 0 .. other.value.sml)
                {
                    ret ~= arr;
                }
                return dynamic(ret);
            }
            if (type == Type.arr && other.type == Type.big)
            {
                Dynamic[] ret;
                foreach (i; 0 .. other.as!size_t)
                {
                    ret ~= arr;
                }
                return dynamic(ret);
            }
        }
        throw new TypeException("invalid types: " ~ type.to!string ~ op ~ other.type.to!string);
    }

    Dynamic opUnary(string op)()
    {
        if (type == Type.sml)
        {
            return dynamic(mixin(op ~ "value.sml"));
        }
        else
        {
            return dynamic(mixin(op ~ "*value.bnm"));
        }
    }

    bool log()
    {
        version (safe)
            if (type != Type.log)
            {
                throw new TypeException("expected logical type");
            }
        return value.log;
    }

    string str()
    {
        version (safe)
            if (type != Type.str)
            {
                throw new TypeException("expected string type");
            }
        return *value.str;
    }

    Array arr()
    {
        version (safe)
            if (type != Type.arr)
            {
                throw new TypeException("expected array type");
            }
        return *value.arr;
    }

    Table tab()
    {
        version (safe)
            if (type != Type.tab)
            {
                throw new TypeException("expected table type");
            }
        return value.tab;
    }

    string* strPtr()
    {
        version (safe)
            if (type != Type.str)
            {
                throw new TypeException("expected string type");
            }
        return value.str;
    }

    Array* arrPtr()
    {
        version (safe)
            if (type != Type.arr)
            {
                throw new TypeException("expected array type");
            }
        return value.arr;
    }

    Value.Callable fun()
    {
        version (safe)
            if (type != Type.fun && type != Type.pro && type != Type.del)
            {
                throw new TypeException("expected callable type");
            }
        return value.fun;
    }

    T as(T)() if (is(T == size_t))
    {
        if (type == Type.sml)
        {
            return cast(size_t) value.sml;
        }
        else
        {
            return mpfr_get_ui(value.bnm.mpfr, mpfr_rnd_t.MPFR_RNDN);
        }
    }

    T as(T)() if (is(T == double))
    {
        if (type == Type.sml)
        {
            return cast(double) value.sml;
        }
        else
        {
            return mpfr_get_d(value.bnm.mpfr, mpfr_rnd_t.MPFR_RNDN);
        }
    }

    bool isTruthy()
    {
        return type != Type.nil && (type != Type.log || value.log);
    }
}

private int cmp(T)(T a, T b) if (!is(T == Function) && !is(T == Dynamic))
{
    if (a == b)
    {
        return 0;
    }
    if (a < b)
    {
        return -1;
    }
    return 1;
}

private int cmpFunction(const Function a, const Function b)
{
    return cmp(cast(void*) a, cast(void*) b);
}

Dynamic[2][] above;
private int cmpDynamic(T...)(T a)
{
    int res = cmpDynamicImpl(a);
    // writeln(a[0], ", ", a[1], " // ", res);
    return res;
}

private int cmpDynamicImpl(const Dynamic a, const Dynamic b)
{
    Dynamic[2] cur = [a, b];
    foreach (i, p; above)
    {
        if (cur[0] is p[0] && cur[1] is p[1])
        {
            return 0;
        }
    }
    if (b.type != a.type)
    {
        if (a.type == Dynamic.Type.sml)
        {
            if (b.type == Dynamic.Type.big)
            {
                return cmp(a.value.sml.asBig, *b.value.bnm);
            }
        }
        if (a.type == Dynamic.Type.big)
        {
            if (b.type == Dynamic.Type.sml)
            {
                return cmp(*a.value.bnm, b.value.sml.asBig);
            }
        }
        return cmp(a.type, b.type);
    }
    if (a is b)
    {
        return 0;
    }
    switch (a.type)
    {
    default:
        assert(0);
    case Dynamic.Type.nil:
        return 0;
    case Dynamic.Type.log:
        return cmp(a.value.log, b.value.log);
    case Dynamic.Type.str:
        return cmp(*a.value.str, *b.value.str);
    case Dynamic.Type.sml:
        return cmp(a.value.sml, b.value.sml);
    case Dynamic.Type.big:
        return cmp(*a.value.bnm, *b.value.bnm);
    case Dynamic.Type.arr:
        above ~= cur;
        scope (exit)
        {
            above.length--;
        }
        const Dynamic[] as = *a.value.arr;
        const Dynamic[] bs = *b.value.arr;
        if (int c = cmp(as.length, bs.length))
        {
            return c;
        }
        foreach (i; 0 .. as.length)
        {
            if (int res = cmpDynamic(as[i], bs[i]))
            {
                return res;
            }
        }
        return 0;
    case Dynamic.Type.tab:
        above ~= cur;
        scope (exit)
        {
            above.length--;
        }
        Table at = cast(Table) a.value.tab;
        Table bt = cast(Table) b.value.tab;
        if (int c = cmp(at.table.length, bt.table.length))
        {
            return c;
        }
        foreach (key, value; at)
        {
            Dynamic aValue = value;
            const Dynamic* bValue = key in bt;
            if (bValue is null)
            {
                foreach (key2, value2; bt)
                {
                    if (key2 !in at)
                    {
                        return cmpDynamic(key, key2);
                    }
                }
                assert(0);
            }
            if (int res = cmpDynamic(aValue, *bValue))
            {
                return res;
            }
        }
        return 0;
    case Dynamic.Type.fun:
        return cmp(a.value.fun.fun, b.value.fun.fun);
    case Dynamic.Type.del:
        return cmp(a.value.fun.del, b.value.fun.del);
    case Dynamic.Type.pro:
        return cmpFunction(a.value.fun.pro, b.value.fun.pro);
    }
}

private string strFormat(Dynamic dyn, Dynamic[] before = null)
{
    foreach (i, v; before)
    {
        if (dyn is v)
        {
            return "&" ~ i.to!string;
        }
    }
    before ~= dyn;
    scope (exit)
    {
        before.length--;
    }
    switch (dyn.type)
    {
    default:
        return "???";
    case Dynamic.Type.nil:
        return "nil";
    case Dynamic.Type.log:
        return dyn.log.to!string;
    case Dynamic.Type.sml:
        return dyn.value.sml.to!string;
    case Dynamic.Type.big:
        return (*dyn.value.bnm).to!string;
    case Dynamic.Type.str:
        if (before.length == 0)
        {
            return dyn.str;
        }
        else
        {
            return '"' ~ dyn.str ~ '"';
        }
    case Dynamic.Type.arr:
        char[] ret;
        ret ~= "[";
        foreach (i, v; dyn.arr)
        {
            if (i != 0)
            {
                ret ~= ", ";
            }
            ret ~= strFormat(v, before);
        }
        ret ~= "]";
        return cast(string) ret;
    case Dynamic.Type.tab:
        char[] ret;
        ret ~= "{";
        size_t i = 0;
        foreach (key, value; dyn.tab)
        {
            if (i != 0)
            {
                ret ~= ", ";
            }
            ret ~= strFormat(key, before);
            ret ~= ": ";
            ret ~= strFormat(value, before);
            i++;
        }
        ret ~= "}";
        return cast(string) ret;
    case Dynamic.Type.fun:
        return "<function>";
    case Dynamic.Type.del:
        return "<function>";
    case Dynamic.Type.pro:
        return dyn.fun.pro.to!string;
    }
}
