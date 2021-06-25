module purr.type.repr;

import std.conv;
import std.array;
import std.algorithm;
import purr.io;
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

    bool check(Args...)(Args args)
    {
        foreach (arg; args)
        {
            if (arg.fits(this))
            {
                return true;
            }
        }
        return false;
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
        assert(false);
    }

    Unk getUnk()
    {
        return cast(Unk) this;
    }

    final T as(T)() if (!is(T == Unk) && !is(T == Lambda) && !is(T == Exactly))
    {
        if (this is null)
        {
            return null;
        }
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

    static Type func(string bc = gen)
    {
        return Func.empty(bc);
    }
    
    static Type join(Type[] args)
    {
        return new Join(args);
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

    static Type dynamic()
    {
        return new Dynamic;
    }

    static Type nil()
    {
        return new Nil;
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
            return "???";
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
    Type[] rets;
    Type[][] cases;
    Node[] args;
    Type delegate(Type[]) runme;

    this(Type delegate(Type[]) spec)
    {
        runme = spec;
    }

    Type specialize(Type[] args)
    {
        Type ret = runme(args);
        cases ~= args;
        rets ~= ret;
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
        string str;
        foreach (i; 0..cases.length)
        {
            if (i != 0)
            {
                str ~= ", ";
            }
            Type ret = rets[i];
            Type[] args = cases[i];
            str ~= "case (";
            str ~= args.to!string[1..$-1];
            str ~= "): ";
            str ~= ret.to!string;
        }
        string ret;
        ret ~= "Generic {";
        ret ~= str;
        ret ~= "}";
        return ret;
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

class Dynamic : Known
{
    override bool fits(Type other)
    {
        return other.as!Dynamic !is null || other.as!Never !is null;
    }

    override size_t size()
    {
        return 8;
    }

    override string toString()
    {
        return "Dynamic";
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
        return "Int";
    }
}

int n = 0;
string gen()
{
    return "fn_" ~ to!string(++n);
}

class Func : Known
{
    Type ret;
    Type[] args;
    string impl;

    static Func empty(string impl = gen)
    {
        return new Func([], Type.unk, impl);
    }

    this(Type[] a, Type r, string ip)
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
        if (other.args.length != args.length)
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

class Join : Known
{
    Type[] elems;

    this(Type[] a)
    {
        elems = a;
    }

    override bool runtime()
    {
        foreach (arg; elems)
        {
            if (arg.runtime)
            {
                return true;
            }
        }
        return false;
    }

    override bool fits(Type t)
    {
        Join other = t.as!Join;
        if (other.elems.length != elems.length)
        {
            return false;
        }
        foreach (index, arg; other.elems)
        {
            if (arg.isUnk && elems[index].isUnk)
            {
                continue;
            }
            if (!elems[index].fits(arg))
            {
                return false;
            }
        }
        return true;
    }

    override size_t size()
    {
        size_t ret = 0;
        foreach (elem; elems)
        {
            ret += elem.size;
        }
        return ret;
    }

    override string toString()
    {
        return `[` ~ elems.map!(to!string).join(`, `) ~ `]`;
    }
}
