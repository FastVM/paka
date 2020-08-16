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
import lang.data.rope;
import lang.base;

public import lang.number : Number;

alias Args = Dynamic[];
alias Array = Dynamic[];
alias Table = Dynamic[Dynamic];

Dynamic dynamic(T...)(T a)
{
    Dynamic ret = Dynamic(a);
    return ret;
}

struct Dynamic
{
    enum Type : ubyte
    {
        nil,
        log,
        num,
        str,
        box,
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
        Number num;
        string str;
        Dynamic* box;
        Array* arr;
        Table* tab;
        union Callable
        {
            Dynamic function(Args) fun;
            Dynamic delegate(Args) del;
            Function pro;
        }

        Callable fun;
    }

align(1):
    Type type;
    Value value;

    this(Type t)
    {
        type = t;
    }

    this(bool log)
    {
        value.log = log;
        type = Type.log;
    }

    this(Number num)
    {
        value.num = num;
        type = Type.num;
    }

    this(string str)
    {
        value.str = str;
        type = Type.str;
    }

    this(Dynamic* box)
    {
        value.box = box;
        type = Type.box;
    }

    this(Array arr)
    {
        value.arr = [arr].ptr;
        type = Type.arr;
    }

    this(Table tab)
    {
        value.tab = [tab].ptr;
        type = Type.tab;
    }

    this(Dynamic function(Args) fun)
    {
        value.fun.fun = fun;
        type = Type.fun;
    }

    this(Dynamic delegate(Args) del)
    {
        value.fun.del = del;
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

    size_t toHash() const nothrow  // override size_t toHash() const nothrow @trusted
    {
        switch (type)
        {
        default:
            return hashOf(type) ^ hashOf(value);
        case Type.str:
            return hashOf(value.str);
        case Type.arr:
            return hashOf(*value.arr);
        case Type.tab:
            return hashOf(*value.tab);
        }
    }

    string toString()
    {
        return this.strFormat;
    }

    Dynamic opCall(Dynamic[] args)
    {
        switch (type)
        {
        case Dynamic.Type.fun:
            return fun.fun(args);
        case Dynamic.Type.del:
            return fun.del(args);
        case Dynamic.Type.pro:
            return run(fun.pro, fun.pro.self, args);
        default:
            throw new Exception("error: not a function: " ~ this.to!string);
        }
    }

    int opCmp(Dynamic other)
    {
        Type t = type;
    before:
        switch (t)
        {
        default:
            assert(0);
        case Type.nil:
            return 0;
        case Type.box:
            t = box.type;
            goto before;
        case Type.log:
            if (value.log == other.log)
            {
                return 0;
            }
            if (value.log < other.log)
            {
                return -1;
            }
            return 1;
        case Type.num:
            if (value.num == other.num)
            {
                return 0;
            }
            if (value.num < other.num)
            {
                return -1;
            }
            return 1;
        case Type.str:
            if (value.str == other.str)
            {
                return 0;
            }
            if (value.str < other.str)
            {
                return -1;
            }
            return 1;
        }
    }

    bool opEquals(const Dynamic other) const
    {
        return isEqual(this, other);
    }

    Dynamic opBinary(string op)(Dynamic other)
    {
        if (type == Type.num && other.type == Type.num)
        {
            Dynamic ret = dynamic(mixin("num" ~ op ~ "other.num"));
            return ret;
        }
        static if (op == "*")
        {
            if (type == Type.str && other.type == Type.num)
            {
                return dynamic(cast(string) str.replicate(cast(size_t) other.num).array);
            }
            if (type == Type.arr && other.type == Type.num)
            {
                return dynamic(arr.replicate(cast(size_t) other.num).array);
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

    Dynamic opOpAssign(string op)(Dynamic other)
    {
        Dynamic ret = mixin("this" ~ op ~ "other");
        type = ret.type;
        value = ret.value;
        return this;
    }

    Dynamic opUnary(string op)()
    {
        return dynamic(mixin(op ~ "value.num"));
    }

    ref bool log()
    {
        if (type == Type.box)
        {
            return value.box.log;
        }
        if (type != Type.log)
        {
            throw new Exception("expected logical type");
        }
        return value.log;
    }

    ref Number num()
    {
        if (type == Type.box)
        {
            return value.box.num;
        }
        if (type != Type.num)
        {
            throw new Exception("expected number type");
        }
        return value.num;
    }

    ref string str()
    {
        if (type == Type.box)
        {
            return value.box.str;
        }
        if (type != Type.str)
        {
            throw new Exception("expected string type");
        }
        return value.str;
    }

    ref Array arr()
    {
        if (type == Type.box)
        {
            return value.box.arr;
        }
        if (type != Type.arr && type != Type.dat)
        {
            throw new Exception("expected array type");
        }
        return *value.arr;
    }

    ref Dynamic unbox()
    {
        return *box;
    }

    ref Dynamic* box()
    {
        if (type != Type.box)
        {
            throw new Exception("expected box type");
        }
        return value.box;
    }

    ref Table tab()
    {
        if (type == Type.box)
        {
            return value.box.tab;
        }
        if (type != Type.tab)
        {
            throw new Exception("expected table type");
        }
        return *value.tab;
    }

    ref Value.Callable fun()
    {
        if (type == Type.box)
        {
            return value.box.fun;
        }
        if (type != Type.fun && type != Type.pro && type != Type.del)
        {
            throw new Exception("expected callable type");
        }
        return value.fun;
    }

}

private bool isEqual(const Dynamic a, const Dynamic b)
{
    if (b.type != a.type)
    {
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
    case Dynamic.Type.num:
        return a.value.num == b.value.num;
    case Dynamic.Type.str:
        return a.value.str == b.value.str;
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
    case Dynamic.Type.num:
        if (dyn.num % 1 == 0)
        {
            return to!string(cast(long) dyn.num);
        }
        return dyn.num.to!string;
    case Dynamic.Type.str:
        if (before.length == 0)
        {
            return dyn.str;
        }
        else
        {
            return '"' ~ dyn.str ~ '"';
        }
    case Dynamic.Type.box:
        return "<box " ~ to!string(*dyn.value.box) ~ ">";
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
