module purr.type.repr;

import purr.io;
import std.conv;
import purr.vm.bytecode;

class Type
{
    bool fits(Type other)
    {
        assert(false, typeid(this).to!string);
    }

    size_t size()
    {
        assert(false, typeid(this).to!string);
    }

    bool isUnk()
    {
        assert(false);
    }

    T as(T)() if (!is(T == Unk))
    {
        if (Unk box = cast(Unk) this)
        {
            return box.next.as!T;            
        }
        return cast(T) this;
    }

    static Type fail()
    {
        return new Fail;
    }

    static Type never()
    {
        return new Never;
    }

    static Type logical()
    {
        return new Logical;
    }

    static Type number()
    {
        return new Number;
    }

    static Type higher(Type other)
    {
        return new Higher(other);
    }

    static Type integer()
    {
        return new Integer;
    }

    static Type func(Bytecode bc)
    {
        return Func.empty(bc);
    }

    static Type nil()
    {
        return new Nil;
    }

    static Type frame()
    {
        return new Frame;
    }

    static Type unk()
    {
        return new Unk;
    }
}

class Unk : Type
{
    Unk[] same;
    Type next;

    override bool isUnk()
    {
        return next is null;
    }

    override size_t size()
    {
        if (isUnk)
        {
            throw new Exception("internal error: size of unknown type");
        }
        return next.size;
    }

    override bool fits(Type other)
    {
        if (isUnk)
        {
            throw new Exception("internal error: match of unknown type");
        }
        return next.fits(other);
    }

    void set(Type found)
    {
        if (!isUnk)
        {
            throw new Exception("internal error: type error");
        }
        if (found.isUnk)
        {
            same ~= cast(Unk) found; 
        }
        if (Unk box = cast(Unk) next)
        {
            box.set(found);
        }
        next = found;
        foreach (s; same)
        {
            if (s.isUnk)
            {
                s.set(found);
            }
        }
    }
    
    override string toString()
    {
        if (isUnk)
        {
            return "?";
        }
        return next.to!string;
    }
}

class Known : Type
{
    override bool isUnk()
    {
        return false;
    }
}

class Higher : Known
{
    Type type;

    this(Type t)
    {
        type = t;
    }

    override bool fits(Type arg)
    {
        Higher other = arg.as!Higher;
        if (other is null)
        {
            return false;
        }
        return type.fits(other.type);
    }

    override string toString()
    {
        return "type(" ~ type.toString  ~ ")";
    }
}

class Fail : Known
{
    override bool fits(Type other)
    {
        return false;
    }

    override string toString()
    {
        return "Fail";
    }
}

class Never : Known
{
    override bool fits(Type other)
    {
        return true;
    }

    override size_t size()
    {
        return 0;
    }

    override string toString()
    {
        return "Never";
    }
}

class Nil : Known
{
    override bool fits(Type other)
    {
        return other.as!Nil !is null || other.as!Never !is null;
    }

    override size_t size()
    {
        return 0;
    }

    override string toString()
    {
        return "Nil";
    }
}

class Frame : Known
{
    override bool fits(Type other)
    {
        return other.as!Frame is null || other.as!Never !is null;
    }

    override size_t size()
    {
        return (Frame*).sizeof;
    }

    override string toString()
    {
        return "Nil";
    }
}

class Logical : Known
{
    override bool fits(Type other)
    {
        return other.as!Logical is null || other.as!Never !is null;
    }

    override size_t size()
    {
        return 1;
    }

    override string toString()
    {
        return "Logical";
    }
}

class Number : Known
{
    override bool fits(Type other)
    {
        return other.as!Number !is null || other.as!Never !is null;
    }

    override size_t size()
    {
        return 8;
    }

    override string toString()
    {
        return "Number";
    }
}

class Integer : Known
{
    override bool fits(Type other)
    {
        return other.as!Integer !is null || other.as!Never !is null;
    }

    override size_t size()
    {
        return 8;
    }

    override string toString()
    {
        return "Integer";
    }
}

class Func : Known
{
    Type ret;
    Type[] args;
    Bytecode impl = null;

    static Func empty(Bytecode impl = Bytecode.empty)
    {
        return new Func([], Type.unk, impl);
    }

    this(Type[] a, Type r, Bytecode ip)
    {
        args = a;
        ret = r;
        impl = ip;
    }

    override bool fits(Type t)
    {
        Func other = t.as!Func;
        if (other is null)
        {
            return false;
        }
        if (ret.isUnk || other.ret.isUnk)
        {
            return false;
        }
        foreach (index, arg; other.args)
        {
            if (!args[index].fits(arg))
            {
                return false;
            }
        }
        return ret.fits(other.ret);
    }

    override size_t size()
    {
        return 8;
    }

    override string toString()
    {
        return "(" ~ args.to!string[1 .. $ - 1] ~ ")" ~ " -> " ~ ret.to!string;
    }
}
