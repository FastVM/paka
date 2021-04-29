module ext.ffi.bind;

import purr.io;
import std.traits;
import std.typecons;
import std.meta;
import std.conv;
import purr.dynamic;
import ext.ffi.unbind;

Dynamic bind(Type)(Type arg) if (isNumeric!Type)
{
    return arg.to!double.dynamic;
}

Dynamic bind(Type)(Type arg) if (is(Type == Dynamic))
{
    return arg;
}

Dynamic bind(Type)(Type arg) if (is(Type == string))
{
    return arg.dynamic;
}

Dynamic bind(Type)(Type arg) if (isArray!Type && !isSomeString!Type)
{
    Array ret;
    foreach (elem; arg)
    {
        ret ~= elem.bind;
    }
    return ret.dynamic;
}

Dynamic bind(Type)(Type arg) if (is(Type == Table) || is(Type == Mapping))
{
    return arg.dynamic;
}

Dynamic bind(Type)(Type arg) if (isAssociativeArray!Type)
{
    Mapping map = emptyMapping;
    foreach (key, value; arg)
    {
        map[key.bind] = value.bind;
    }
    return new Table(map).dynamic;
}

Dynamic bind(Type)(Type args) if (isTuple!Type)
{
    Array arr;
    static foreach (argno; 0 .. Type.length)
    {
        static if (isSomeFunction!(Type[argno]))
        {
            arr ~= bind!(Type[argno]);
        }
        else
        {
            arr ~= args[argno].bind;
        }
    }
    return Dynamic.tuple(arr);
}

Dynamic[] arr(Args...)(Args args)
{
    Array ret;
    static foreach (arg; args)
    {
        ret ~= arg.bind;
    }
    return ret;
}

Table tab(Args...)(Args args)
{
    static assert(args.length % 2 == 0);
    Mapping map = emptyMapping;
    static foreach (n; 0..args.length/2)
    {
        map[args[n*2].bind] = args[n*2+1].bind;
    }
    return new Table(map);
}



template bind(alias func) if (isFunction!func)
{
    alias Ret = ReturnType!func;
    alias Params = Parameters!func;

    Dynamic bound(Args args)
    {
        Params params;
        static foreach (ind; 0 .. params.length)
        {
            params[ind] = args[ind].unbind!(Params[ind]);
        }
        return func(params).bind;
    }

    Dynamic bind()
    {
        Fun fun = native!bound;
        fun.names = [__traits(identifier, func).dynamic];
        return fun.dynamic;
    }
}
