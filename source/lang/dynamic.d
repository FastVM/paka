module lang.dynamic;

import std.algorithm;
import std.conv;
import std.format;
import std.functional;
import std.math;
import std.traits;
import std.typecons;
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

alias dynamic = Dynamic;

Dynamic nil() {
    return dynamic.init;
}
Dynamic ltrue = dynamic(true);
Dynamic lfalse = dynamic(false);

struct Dynamic
{
    enum Type : ubyte
    {
        nil,
        log,
        num,
        str,
        arr,
        tab,
        fun,
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
        Array* arr;
        Table* tab;
        union Callable
        {
            Dynamic function(Args) fun;
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
        // value.str = cast(string*) GC.malloc(string.sizeof);
        // *value.str = str;
        value.str = str;
        // value.str = new string(str);
        type = Type.str;
    }

    this(Array arr)
    {
        value.arr = cast(Dynamic[]*) GC.malloc((Dynamic[]).sizeof);
        *value.arr = arr;
        type = Type.arr;
    }

    this(Table tab)
    {
        value.tab = cast(Dynamic[Dynamic]*) GC.malloc((Dynamic[Dynamic]).sizeof);
        *value.tab = tab;
        type = Type.tab;
    }

    this(Dynamic function(Args) fun)
    {
        value.fun.fun = fun;
        type = Type.fun;
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

    string toString()
    {
        return this.strFormat;
    }

    int opCmp(Dynamic other)
    {
        switch (type)
        {
        default:
            assert(0);
        case Type.nil:
            return 0;
        case Type.log:
            if (value.log == other.value.log)
            {
                return 0;
            }
            if (value.log < other.value.log)
            {
                return -1;
            }
            return 1;
        case Type.num:
            if (value.num == other.value.num)
            {
                return 0;
            }
            if (value.num < other.value.num)
            {
                return -1;
            }
            return 1;
        case Type.str:
            if (value.str == other.value.str)
            {
                return 0;
            }
            if (value.str < other.value.str)
            {
                return -1;
            }
            return 1;
        }
    }

    bool opEquals(const Dynamic other) const
    {
        if (other.type != type)
        {
            return false;
        }
        if (this.value == other.value)
        {
            return true;
        }
        switch (type)
        {
        default:
            assert(0);
        case Type.nil:
            return true;
        case Type.log:
            return value.log == other.value.log;
        case Type.num:
            return value.num == other.value.num;
        case Type.str:
            return value.str == other.value.str;
        case Type.arr:
            return *value.arr == *other.value.arr;
        case Type.tab:
            return *value.tab == *other.value.tab;
        case Type.fun:
            return value.fun.fun == other.value.fun.fun;
        case Type.pro:
            return value.fun.pro == other.value.fun.pro;
        }
    }

    size_t toHash() const nothrow
    {
        switch (type)
        {
        default:
            return hashOf(this.type) ^ hashOf(this.value);
        case Type.str:
            return hashOf(value.str);
        case Type.arr:
            return hashOf(*value.arr);
        case Type.tab:
            return hashOf(*value.tab);
        }
    }

    Dynamic opBinary(string op)(Dynamic other) {
        return dynamic(mixin("value.num" ~ op ~ "other.value.num"));
    }

    Dynamic opUnary(string op)() {
        return dynamic(mixin(op ~ "value.num"));
    }

    Dynamic opOpAssign(string op)(Dynamic other) {
        mixin("value.num" ~ op ~ "=other.value.num;");
        return this;
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
        return dyn.value.log.to!string;
    case Dynamic.Type.num:
        if (dyn.value.num % 1 == 0)
        {
            return to!string(cast(long) dyn.value.num);
        }
        return dyn.value.num.to!string;
    case Dynamic.Type.str:
        return dyn.value.str;
    case Dynamic.Type.arr:
        char[] ret;
        ret ~= "[";
        foreach (i, v; *dyn.value.arr)
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
        foreach (v; dyn.value.tab.byKeyValue)
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
        return serialLookup[dyn.value.fun.fun];
    case Dynamic.Type.pro:
        return dyn.value.fun.pro.to!string;
    }
}
