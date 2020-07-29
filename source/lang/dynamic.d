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

Dynamic nil()
{
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
        value.str = str;
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

    Dynamic opBinary(string op)(Dynamic other)
    {
        if (type == Type.num && other.type == Type.num)
        {
            return dynamic(mixin("value.num" ~ op ~ "other.num"));
        }
        if (type == Type.str && other.type == Type.str)
        {
            static if (op == "~" || op == "+") {
                return dynamic(mixin("value.str~other.str"));
            }
        }
        throw new Exception("invalid types: " ~ type.to!string ~ ", " ~ other.type.to!string);
    }

    Dynamic opUnary(string op)()
    {
        return dynamic(mixin(op ~ "value.num"));
    }

    Dynamic opOpAssign(string op)(Dynamic other)
    {
        if (type == Type.num && other.type == Type.num)
        {
            dynamic(mixin("num" ~ op ~ "=other.num"));
            return this;
        }
        if (type == Type.str && other.type == Type.str)
        {
            static if (op == "~" || op == "+") {
                dynamic(mixin("str~=other.str"));
                return this;
            }
        }
        throw new Exception("invalid types: " ~ type.to!string ~ ", " ~ other.type.to!string);
    }

    ref bool log()
    {
        if (type != Type.log)
        {
            throw new Exception("expected logical type");
        }
        return value.log;
    }

    ref Number num()
    {
        if (type != Type.num)
        {
            throw new Exception("expected number type");
        }
        return value.num;
    }

    ref string str()
    {
        if (type != Type.str)
        {
            throw new Exception("expected string type");
        }
        return value.str;
    }

    ref Array arr()
    {
        if (type != Type.arr)
        {
            throw new Exception("expected array type");
        }
        return *value.arr;
    }

    ref Table tab()
    {
        if (type != Type.tab)
        {
            throw new Exception("expected table type");
        }
        return *value.tab;
    }

    ref Value.Callable fun()
    {
        if (type != Type.fun && type != Type.pro)
        {
            throw new Exception("expected callable type");
        }
        return value.fun;
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
        return dyn.str;
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
        return serialLookup[dyn.fun.fun];
    case Dynamic.Type.pro:
        return dyn.fun.pro.to!string;
    }
}
