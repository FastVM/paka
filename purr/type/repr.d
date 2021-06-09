module purr.type.repr;

import purr.io;
import std.conv;
import purr.vm.bytecode;
import purr.ast.ast;

class Type
{
    void delegate(Known)[] thens;

    void then(void delegate(Known) arg)
    {
        if (Known kn = this.as!Known)
        {
            arg(kn);
        }
        else
        {
            thens ~= arg;
        }
    }

    void resolve(Type arg)
    {
        if (arg.isUnk) 
        {
            arg.thens ~= thens;
        }
        else
        {
            Known known = arg.as!Known;
            foreach (run; thens)
            {
                run(known);
            }
        }
        thens = null;
    }

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
        assert(false, typeid(this).to!string);
    }

    bool runtime()
    {
        // return true;
        assert(false);
    }

    Unk getUnk()
    {
        return cast(Unk) this;
    }

    T as(T)() if (!is(T == Unk) && !is(T == Lambda) && !is(T == Exactly))
    {
        if (Unk box = this.getUnk)
        {
            return box.next.as!T;            
        }
        if (Lambda fun = cast(Lambda) this)
        {
            return fun.get.as!T;
        }
        if (Exactly exa = cast(Exactly) this)
        {
            return exa.rough.as!T;
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

    static Type float_()
    {
        return new Float;
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

    static Type lambda(Type delegate() dg)
    {
        return new Lambda(dg);
    }

    static Type text()
    {
        return new Text;
    }

    static Type generic(Type delegate(Type[]) spec)
    {
        return new Generic(spec);
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

class Lambda : Type
{
    private Type delegate() run;
    private Type got;

    Type get()
    {
        if (got is null)
        {
            got = run();
        }
        return got;
    }

    this(Type delegate() dg)
    {
        run = dg;
    }

    override size_t size()
    {
        return get.size;
    }

    override Unk getUnk()
    {
        return get.getUnk;
    }

    override bool isUnk()
    {
        return get.isUnk;
    }

    override bool fits(Type other)
    {
        return get.fits(other);
    }

    override bool runtime()
    {
        return get.runtime;
    }
    
    override string toString()
    {
        return get.to!string;
    }
}

class Unk : Type
{
    Unk[] same;
    Known next;

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

    override bool runtime()
    {
        assert(!isUnk);
        return next.runtime;
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
        if (Exactly exa = cast(Exactly) found)
        {
            found = exa.rough;
        }
        if (found.isUnk)
        {
            Unk other = found.getUnk;
            same ~= other;
            other.same ~= this; 
        }
        else if (next is null)
        {
            next = found.as!Known;
            resolve(next);
            Unk[] iter = same;
            same = null;
            foreach (s; iter)
            {
                if (s.isUnk)
                {
                    s.set(found);
                }
            }
        }
        else
        {
            // writeln(next);
            if (Unk box = next.getUnk)
            {
                box.set(found);
            }
            next = found.as!Known;
            resolve(next);
            Unk[] iter = same;
            same = null;
            foreach (s; iter)
            {
                if (s.isUnk)
                {
                    s.set(found);
                }
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

    override bool runtime()
    {
        return false;
    }
}

class Exactly : Type
{
    Known rough;
    void[] data;

    this(Known r, void[] d)
    {
        rough = r;
        data = d;
    } 
    
    override void then(void delegate(Known) arg)
    {
        arg(rough);
    }

    override bool isUnk()
    {
        return false;
    }
    
    override size_t size()
    {
        return rough.size;
    }

    override bool fits(Type arg)
    {
        Exactly other = cast(Exactly) arg;
        if (other is null)
        {
            // return false;
            return rough.fits(arg);
        }
        if (!rough.fits(other.rough))
        {
            return false;
        }
        return true;
    }

    override bool runtime()
    {
        return rough.runtime;
    }

    override string toString()
    {
        return rough.to!string;
    }
}

class Generic : Known
{
    Type delegate(Type[]) runme;

    this(Type delegate(Type[]) spec)
    {
        runme = spec;
    }

    Type specialize(Type[] args)
    {
        Type ret = runme(args);
        resolve(ret);
        return ret;
    }

    override bool fits(Type other)
    {
        return other.as!Generic !is null && this is other;
    }

    override bool runtime()
    {
        return false;
    }

    override size_t size()
    {
        return 0;
    }    

    override string toString()
    {
        return "Generic(...)";
    }
}

class Higher : Known
{
    Type type;

    this(Type t)
    {
        type = t;
    }
    
    override bool runtime()
    {
        return false;
    }

    override size_t size()
    {
        return 0;
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
        return other.as!Logical !is null || other.as!Never !is null;
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

class Text : Known
{
    override bool fits(Type other)
    {
        return other.as!Text !is null || other.as!Never !is null;
    }

    override size_t size()
    {
        return 8;
    }

    override string toString()
    {
        return "Text";
    }
}

class Float : Known
{
    override bool fits(Type other)
    {
        return other.as!Float !is null || other.as!Never !is null;
    }

    override size_t size()
    {
        return 8;
    }

    override string toString()
    {
        return "Float";
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

    override bool runtime()
    {
        return impl is null;
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
            if (arg.isUnk && args[index].isUnk)
            {
                continue;
            }
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
