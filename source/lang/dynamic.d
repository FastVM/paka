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
import lang.number;
import lang.data.rope;
import lang.data.mpfr;

public import lang.number;

alias Args = Dynamic[];
alias Array = Dynamic[];
alias Table = Dynamic[Dynamic];

version = safe;

bool fastMathNotEnabled = false;

pragma(inline, true) Dynamic dynamic(T...)(T a)
{
    return Dynamic(a);
}

struct Dynamic
{
    enum Type: long
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
        dat,
    }

    union Value
    {
        bool log;
        SmallNumber sml;
        BigNumber* bnm;
        string* str;
        Array* arr;
        Table* tab;
        union Callable
        {
            Dynamic function(Args) fun;
            Dynamic delegate(Args)* del;
            Function pro;
        }

        Callable fun;

        BigNumber big() const
        {
            return *bnm;
        }
    }

    Type type = Type.nil;
    Value value = void;

    pragma(inline, true) static Dynamic strToNum(string s)
    {
        BigNumber big = BigNumber(s);
        if (big.fits && !fastMathNotEnabled)
        {
            return dynamic(SmallNumber(mpfr_get_d(big, mpfr_rnd_t.MPFR_RNDN)));
        }
        return dynamic(big);
    }

    pragma(inline, true) this(Type t)
    {
        type = t;
    }

    pragma(inline, true) this(bool log)
    {
        value.log = log;
        type = Type.log;
    }

    pragma(inline, true) this(SmallNumber num)
    {
        value.sml = num;
        type = Type.sml;
    }

    pragma(inline, true) this(BigNumber num)
    {
        value.bnm = new BigNumber(num);
        type = Type.big;
    }

    pragma(inline, true) this(string str)
    {
        value.str = [str].ptr;
        type = Type.str;
    }

    pragma(inline, true) this(Array arr)
    {
        value.arr = [arr].ptr;
        type = Type.arr;
    }

    pragma(inline, true) this(Table tab)
    {
        value.tab = [tab].ptr;
        type = Type.tab;
    }

    pragma(inline, true) this(Dynamic function(Args) fun)
    {
        value.fun.fun = fun;
        type = Type.fun;
    }

    pragma(inline, true) this(Dynamic delegate(Args) del)
    {
        value.fun.del = [del].ptr;
        type = Type.del;
    }

    pragma(inline, true) this(Function pro)
    {
        value.fun.pro = pro;
        type = Type.pro;
    }

    pragma(inline, true) this(Dynamic other)
    {
        value = other.value;
        type = other.type;
    }

    pragma(inline, true) static Dynamic nil()
    {
        Dynamic ret = dynamic(false);
        ret.value = Dynamic.Value.init;
        ret.type = Dynamic.Type.nil;
        return ret;
    }

    pragma(inline, true) size_t toHash() const nothrow  // override size_t toHash() const nothrow @trusted
    {
        switch (type)
        {
        default:
            return hashOf(type) ^ hashOf(value);
        case Type.str:
            return hashOf(*value.str);
        case Type.arr:
            return hashOf(*value.arr);
        case Type.tab:
            return hashOf(*value.tab);
        }
    }

    pragma(inline, true) string toString()
    {
        return this.strFormat;
    }

    pragma(inline, true) Dynamic opCall(Dynamic[] args)
    {
        switch (type)
        {
        case Dynamic.Type.fun:
            return fun.fun(args);
        case Dynamic.Type.del:
            return (*fun.del)(args);
        case Dynamic.Type.pro:
            return run(fun.pro, fun.pro.self, args);
        default:
            throw new Exception("error: not a function: " ~ this.to!string);
        }
    }

    pragma(inline, true) long opCmp(Dynamic other)
    {
        Type t = type;
        switch (t)
        {
        default:
            assert(0);
        case Type.nil:
            return 0;
        case Type.log:
            return value.log - other.log;
        case Type.sml:
            if (other.type == Type.big)
            {
                return value.sml.asBig.opCmp(other.value.big);
            }
            SmallNumber a = value.sml;
            SmallNumber b = other.value.sml;
            if (a < b)
            {
                return -1;
            }
            if (a == b)
            {
                return 1;
            }
            return 0;
        case Type.big:
            if (other.type == Type.sml)
            {
                return value.big.opCmp(other.value.sml.asBig);
            }
            return value.big.opCmp(other.value.big);
        case Type.str:
            return cmp(*value.str, other.str);
        }
    }

    pragma(inline, true) bool opEquals(const Dynamic other) const
    {
        return isEqual(this, other);
    }

    Dynamic opBinary(string op)(Dynamic other)
    {
        if (type == Type.sml)
        {
            if (other.type == Type.sml)
            {
                SmallNumber res = mixin("value.sml" ~ op ~ "other.value.sml");
                if (res.fits)
                {
                    return dynamic(res);
                }
                else
                {
                    return dynamic(mixin("value.sml.asBig" ~ op ~ "other.value.sml.asBig"));
                }
            }
            else if (other.type == Type.big)
            {
                return dynamic(mixin("value.sml.asBig" ~ op ~ "other.value.big"));
            }
        }
        else if (type == Type.big)
        {
            if (other.type == Type.sml)
            {
                return dynamic(mixin("value.big" ~ op ~ "other.value.sml.asBig"));
            }
            else if (other.type == Type.big)
            {
                return dynamic(mixin("value.big" ~ op ~ "other.value.big"));
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
        throw new Exception("invalid types: " ~ type.to!string ~ ", " ~ other.type.to!string);
    }

    pragma(inline, true) Dynamic opOpAssign(string op)(Dynamic other)
    {
        Dynamic ret = mixin("this" ~ op ~ "other");
        type = ret.type;
        value = ret.value;
        return this;
    }

    pragma(inline, true) Dynamic opUnary(string op)()
    {
        if (type == Type.sml)
        {
            return dynamic(mixin(op ~ "value.sml"));
        }
        else
        {
            return dynamic(mixin(op ~ "value.big"));
        }
    }

    pragma(inline, true) bool log()
    {
        version (safe)
            if (type != Type.log)
            {
                throw new Exception("expected logical type");
            }
        return value.log;
    }

    pragma(inline, true) string str()
    {
        version (safe)
            if (type != Type.str)
            {
                throw new Exception("expected string type");
            }
        return *value.str;
    }

    pragma(inline, true) Array arr()
    {
        version (safe)
            if (type != Type.arr && type != Type.dat)
            {
                throw new Exception("expected array type");
            }
        return *value.arr;
    }

    pragma(inline, true) Table tab()
    {
        version (safe)
            if (type != Type.tab)
            {
                throw new Exception("expected table type");
            }
        return *value.tab;
    }

    pragma(inline, true) string* strPtr()
    {
        version (safe)
            if (type != Type.str)
            {
                throw new Exception("expected string type");
            }
        return value.str;
    }

    pragma(inline, true) Array* arrPtr()
    {
        version (safe)
            if (type != Type.arr && type != Type.dat)
            {
                throw new Exception("expected array type");
            }
        return value.arr;
    }

    pragma(inline, true) Table* tabPtr()
    {
        version (safe)
            if (type != Type.tab)
            {
                throw new Exception("expected table type");
            }
        return value.tab;
    }

    pragma(inline, true) Value.Callable fun()
    {
        version (safe)
            if (type != Type.fun && type != Type.pro && type != Type.del)
            {
                throw new Exception("expected callable type");
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
            return mpfr_get_ui(value.big.mpfr, mpfr_rnd_t.MPFR_RNDN);
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
            return mpfr_get_d(value.big.mpfr, mpfr_rnd_t.MPFR_RNDN);
        }
    }
}

pragma(inline, true) private bool isEqual(const Dynamic a, const Dynamic b)
{
    if (b.type != a.type)
    {
        if (a.type == Dynamic.Type.sml)
        {
            if (b.type == Dynamic.Type.big)
            {
                return a.value.sml.asBig == b.value.big;
            }
        }
        if (a.type == Dynamic.Type.big)
        {
            if (b.type == Dynamic.Type.sml)
            {
                return a.value.big == b.value.sml.asBig;
            }
        }
        return false;
    }
    if (a.value == b.value)
    {
        return true;
    }
    switch (a.type)
    {
    default:
        assert(0);
    case Dynamic.Type.nil:
        return true;
    case Dynamic.Type.log:
        return a.value.log == b.value.log;
    case Dynamic.Type.str:
        return *a.value.str == *b.value.str;
    case Dynamic.Type.sml:
        return a.value.sml == b.value.sml;
    case Dynamic.Type.big:
        return a.value.big == b.value.big;
    case Dynamic.Type.arr:
        return *a.value.arr == *b.value.arr;
    case Dynamic.Type.tab:
        return *a.value.tab == *b.value.tab;
    case Dynamic.Type.fun:
        return a.value.fun.fun == b.value.fun.fun;
    case Dynamic.Type.del:
        return a.value.fun.del == b.value.fun.del;
    case Dynamic.Type.pro:
        return a.value.fun.pro == b.value.fun.pro;
    }
}

private string strFormat(Dynamic dyn, Dynamic[] before = null)
{
    if (canFind(before, dyn))
    {
        return "...";
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
        return dyn.value.big.to!string;
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
        size_t i;
        foreach (v; dyn.tab.byKeyValue)
        {
            if (i != 0)
            {
                ret ~= ", ";
            }
            ret ~= strFormat(v.key, before);
            ret ~= ": ";
            ret ~= strFormat(v.value, before);
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
