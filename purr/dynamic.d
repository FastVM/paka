module purr.dynamic;

import core.sync.mutex;
import core.memory;
import core.atomic;
import std.algorithm;
import std.conv;
import std.array;
import std.traits;
import purr.io;
import purr.vm.bytecode;
import purr.vm;
import purr.data.map;
import purr.data.rope;
import purr.plugin.syms;

version = safe;

alias Args = Dynamic[];
alias Array = Dynamic[];

alias Delegate = Dynamic function(Args);
alias Mapping = Dynamic[Dynamic];
pragma(inline, true):
Mapping emptyMapping()
{
    return Mapping.init;
}

private __gshared size_t symc = 0;
Dynamic gensym()
{
    synchronized
    {
        return dynamic(symc++);
    }
}

Dynamic dynamic(T...)(T a)
{
    return Dynamic(a);
}

struct Dynamic
{
    enum Type : char
    {
        nil,
        log,
        sml,
        str,
        arr,
        fun,
        err,
    }

    union Value
    {
        bool log;
        double sml;
        string* str;
        List* arr;
        Bytecode fun;
        Error err;
    }

    enum Error
    {
        unknown,
        oom,
        opcode,
    }

    Value value = void;
    Type type = void;

pragma(inline, true):
    static Dynamic strToNum(string s)
    {
        return dynamic(s.to!double);
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

    this(double num)
    {
        value.sml = num;
        type = Type.sml;
    }

    this(string str)
    {
        value.str = cast(string*) GC.calloc(string.sizeof);
        *value.str = str;
        type = Type.str;
    }

    this(Array arr)
    {
        type = Type.arr;
        assert(false);
    }

    this(Bytecode fun)
    {
        value.fun = fun;
        type = Type.fun;
    }

    this(Dynamic other)
    {
        set(other);
    }

    void set(Dynamic other)
    {
        type = other.type;
        value = other.value;
    }

    static Dynamic nil()
    {
        Dynamic ret = dynamic(false);
        ret.value = Dynamic.Value.init;
        ret.type = Type.nil;
        return ret;
    }

    size_t toHash() const nothrow
    {
        final switch (type)
        {
        case Type.nil:
            return 0;
        case Type.log:
            if (value.log)
            {
                return 1;
            }
            else
            {
                return 2;
            }
        case Type.sml:
            if (value.sml > 0)
            {
                return 3 + cast(size_t) value.sml;
            }
            else
            {
                return 3 + cast(size_t)-value.sml;
            }
        case Type.str:
            return (*value.str).hashOf;
        case Type.arr:
            return cast(size_t) value.arr.length + (1L << 32);
        case Type.fun:
            return size_t.max - 2;
        case Type.err:
            assert(false);
        }
    }

    bool opEquals(const Dynamic other) const
    {
        if (other.type != type)
        {
            return false;
        }
        switch (type)
        {
        default:
            assert(false);
        case Type.nil:
            return 0;
        case Type.log:
            return value.log == other.value.log;
        case Type.str:
            return *value.str == *other.value.str;
        case Type.sml:
            return value.sml == other.value.sml;
        case Type.arr:
            Dynamic[2] cur = [this, other];
            foreach (i, p; above)
            {
                if (cur[0] is p[0] && cur[1] is p[1])
                {
                    return false;
                }
            }
            above ~= cur;
            scope (exit)
            {
                above.length--;
            }
            if (value.arr.length != other.value.arr.length)
            {
                return false;
            }
            foreach (i; 0 .. value.arr.length)
            {
                if (value.arr.index!Dynamic(i) != other.value.arr.index!Dynamic(i))
                {
                    return false;
                }
            }
            return true;
        case Type.fun:
            return value.fun is other.value.fun;
        }
    }

    bool opBinary(string op: "is")(const Dynamic other) const
    {
        if (other.type != type)
        {
            return false;
        }
        switch (type)
        {
        default:
            assert(false);
        case Type.nil:
            return true;
        case Type.log:
            return value.log == other.value.log;
        case Type.sml:
            return value.sml == other.value.sml;
        case Type.str:
            return cast(void*) value.str == cast(void*) other.value.str;
        case Type.arr:
            return cast(void*) value.arr == cast(void*) other.value.arr;
        case Type.fun:
            return cast(void*) value.fun == cast(void*) other.value.fun;
        }
    }

    bool log()
    {

        version (safe)
        {
            if (type != Type.log)
            {
                throw new Exception("expected logical type (not: " ~ this.to!string ~ ")");
            }
        }
        return value.log;
    }

    string str()
    {

        version (safe)
        {
            if (type != Type.str)
            {
                throw new Exception("expected string type (not: " ~ this.to!string ~ ")");
            }
        }
        return *value.str;
    }

    Array arr()
    {

        version (safe)
        {
            if (!isArray)
            {
                throw new Exception("expected array type (not: " ~ this.to!string ~ ")");
            }
        }
        return value.arr.ptr!Dynamic[0 .. value.arr.length];
    }

    string* strPtr()
    {

        version (safe)
        {
            if (type != Type.str)
            {
                throw new Exception("expected string type (not: " ~ this.to!string ~ ")");
            }
        }
        return value.str;
    }

    T as(T)() if (isIntegral!T)
    {

        if (type == Type.sml)
        {
            return cast(T) value.sml;
        }
        else
        {
            throw new Exception("expected numeric type (not: " ~ this.to!string ~ ")");
        }
    }

    T as(T)() if (isFloatingPoint!T)
    {

        if (type == Type.sml)
        {
            return cast(T) value.sml;
        }
        else
        {
            throw new Exception("expected numeric type (not: " ~ this.to!string ~ ")");
        }
    }

    bool isNil()
    {

        return type == Type.nil;
    }

    bool isString()
    {

        return type == Type.str;
    }

    bool isNumber()
    {

        return type == Type.sml;
    }

    bool isArray()
    {
        assert(false);

        return type == Type.arr;
    }

    bool isError()
    {
        return type == Type.err;
    }

    bool isTruthy()
    {

        return type != Type.nil && (type != Type.log || value.log);
    }

    string toString() const
    {
        Dynamic dyn = cast(Dynamic) this;
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
            return "<?" ~ dyn.type.to!string ~ ">";
        case Type.nil:
            return "nil";
        case Type.log:
            return dyn.log.to!string;
        case Type.sml:
            if (dyn.value.sml % 1 == 0 && dyn.value.sml > long.min && dyn.value.sml < long.max)
            {
                return to!string(cast(long) dyn.value.sml);
            }
            return dyn.value.sml.to!string;
        case Type.str:
            return dyn.str;
        case Type.arr:
            char[] ret;
            ret ~= "[";
            foreach (i, v; dyn.arr)
            {
                if (i != 0)
                {
                    ret ~= ", ";
                }
                ret ~= v.to!string;
            }
            ret ~= "]";
            return cast(string) ret;
        case Type.fun:
            return "Function(" ~ dyn.value.fun.to!string ~ ")";
        }
    }
}

private Dynamic[] before;
private Dynamic[2][] above;
