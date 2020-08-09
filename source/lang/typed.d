module lang.typed;

import lang.ast;
import lang.bytecode;
import lang.dynamic;
import std.stdio;
import std.conv;
import std.string;
import std.algorithm;

class Type
{
    enum Kind
    {
        nil,
        logical,
        number,
        string,
        callable,
        many,
        any,
        transform,
    }

    union Value
    {
        Type[] types;
        Type delegate(ref Type[]) func;
    }

    Kind kind;
    Value value;
    bool okay = true;

    this(Kind k, Type[] types = null)
    {
        okay = true;
        kind = k;
        value.types = types;
    }

    this(T...)(Kind k, T types) if (T.length > 0)
    {
        okay = true;
        kind = k;
        value.types = [types[]];
    }

    this(Type delegate(ref Type[]) func)
    {
        okay = true;
        kind = Kind.transform;
        value.func = func;
    }

    static Type bad()
    {
        Type ret = new Type(Type.Kind.nil);
        ret.okay = false;
        return ret;
    }

    bool eat(ref Type[] types)
    {
        // writeln(this, " <- ", types);
        final switch (kind)
        {
        case Type.Kind.nil:
            bool ret = types[0].kind == Type.Kind.nil;
            types = types[1 .. $];
            return ret;
        case Type.Kind.logical:
            bool ret = types[0].kind == Type.Kind.logical;
            types = types[1 .. $];
            return ret;
        case Type.Kind.number:
            bool ret = types[0].kind == Type.Kind.number;
            types = types[1 .. $];
            return ret;
        case Type.Kind.string:
            bool ret = types[0].kind == Type.Kind.string;
            types = types[1 .. $];
            return ret;
        case Type.Kind.callable:
            bool iscall = types[0].kind == Type.Kind.callable;
            if (!iscall)
            {
                return false;
            }
            Type[] arr = types[0].value.types[0 .. 1];
            bool retmatch = value.types[0].eat(arr);
            if (!retmatch || arr.length != 0)
            {
                return false;
            }
            types[0].value.types = types[0].value.types[1 .. $];
            foreach (cur; value.types[1 .. $])
            {
                bool egot = cur.eat(types[0].value.types);
                if (!egot)
                {
                    return false;
                }
            }
            bool ret = types[0].value.types.length == 0;
            types = types[1 .. $];
            return ret;
        case Type.Kind.many:
            while (value.types.length > 0 && types.length > 0)
            {
                if (!value.types[0].eat(types))
                {
                    break;
                }
            }
            return true;
        case Type.Kind.any:
            types = types[1 .. $];
            return true;
        case Type.Kind.transform:
            Type type = value.func(types);
            return type.okay;
        }
    }

    override string toString()
    {
        if (kind == Kind.many)
        {
            return kind.to!string ~ value.types.to!string;
        }
        return kind.to!string;
    }
}

class Typer
{
    Type[string][] locals;

    this()
    {
        locals.length++;
        locals[$ - 1]["print"] = new Type(Type.Kind.callable,
                new Type(Type.Kind.nil), new Type(Type.Kind.many, new Type(Type.Kind.any)));
    }

    Type lookup(string name)
    {
        foreach_reverse (layer; locals)
        {
            if (name in layer)
            {
                return layer[name];
            }
        }
        throw new Exception("name not found: " ~ name);
    }

    Type annot(Node node)
    {
        TypeInfo info = typeid(node);
        foreach (T; NodeTypes)
        {
            if (info == typeid(T))
            {
                Type ret = annot(cast(T) node);
                // writeln(ret);
                return ret;
            }
        }
        assert(0);
    }

    Type annot(Call call)
    {
        Type ret = annot(call.args[0]);
        Type[] rest;
        foreach (arg; call.args[1 .. $])
        {
            rest ~= annot(arg);
        }
        switch (ret.kind)
        {
        default:
            throw new Exception("Type error: cannot call object of type: " ~ ret.to!string);
        case Type.Kind.callable:
            foreach (cur; ret.value.types[1 .. $])
            {
                if (!cur.eat(rest))
                {
                    throw new Exception("Type error: bad argument types");
                }
            }
            if (rest.length != 0)
            {
                throw new Exception("Type error: not enough arguments");
            }
            return ret.value.types[0];
        case Type.Kind.transform:
            ret = ret.value.func(rest);
            if (!ret.okay)
            {
                throw new Exception("Type error: bad type (ast: " ~ call.to!string ~ ")");
            }
            return ret;
        }
    }

    Type annot(String str)
    {
        return new Type(Type.Kind.string);
    }

    Type annot(Ident id)
    {
        switch (id.repr)
        {
        default:
            if (id.repr.isNumeric)
            {
                return new Type(Type.Kind.number);
            }
            return lookup(id.repr);
        case "@do":
            return new Type(&doTransform);
        case "-":
            return new Type(&minusTransform);
        case "+":
            return new Type(&addTransform);
        }
        assert(0);
    }

    Type doTransform(ref Type[] args)
    {
        if (args.length == 0)
        {
            return new Type(Type.Kind.nil);
        }
        return args[$ - 1];
    }

    Type minusTransform(ref Type[] args)
    {
        if (args.length == 2)
        {
            if (args[0].kind != args[1].kind)
            {
                return Type.bad;
            }
            if (args[0].kind != Type.Kind.number)
            {
                return new Type(Type.Kind.number);
            }
            return Type.bad;
        }
        if (args.length == 1)
        {
            if (args[0].kind != Type.Kind.number)
            {
                return Type.bad;
            }
            return new Type(Type.Kind.number);
        }
        return Type.bad;
    }

    Type addTransform(ref Type[] args)
    {
        if (args.length != 2)
        {
            return Type.bad;
        }
        if (args[0].kind != args[1].kind)
        {
            return Type.bad;
        }
        if (args[0].kind == Type.Kind.number)
        {
            return new Type(Type.Kind.number);
        }
        if (args[0].kind == Type.Kind.string)
        {
            return new Type(Type.Kind.string);
        }
        return Type.bad;
    }
}
