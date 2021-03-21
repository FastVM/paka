module serial.tojson;

import purr.io;
import std.conv;
import std.format;
import std.algorithm;
import std.math;
import std.traits;
import std.array;
import purr.base;
import purr.srcloc;
import purr.dynamic;
import purr.bytecode;
import purr.plugin.plugin;
import purr.plugin.plugins;
import serial.cons;

Dynamic[] above;

string elem(string name, Arg)(Arg arg)
{
    return `"%s": %s`.format(name, mixin(`arg.` ~ name).serialize);
}

string elems(string names, Arg)(Arg arg)
{
    string ret = `{`;
    static foreach (index, name; names.splitter(" ").array)
    {
        if (index != 0)
        {
            ret ~= `,`;
        }
        ret ~= arg.elem!name;
    }
    ret ~= `}`;
    return ret;
}

string serialize(char chr)
{
    return chr.to!byte
        .to!string;
}

string serialize(Location location)
{
    return location.elems!"line column file";
}

string serialize(Span span)
{
    return span.elems!"first last";
}

string serialize(Pair pair)
{
    return pair.elems!"name val";
}

string serialize(bool b)
{
    return b.to!string;
}

string serialize(Int)(Int i)
        if (std.traits.isIntegral!Int && Int.sizeof < double.sizeof)
{
    return i.to!string;
}

string serialize(Int)(Int i)
        if (std.traits.isIntegral!Int && Int.sizeof >= double.sizeof)
{
    return i.to!string
        .to!string;
}

string serialize(string str)
{
    string ret = `"`;
    foreach (v; str)
    {
        if ("\b\f\n\r\t\"".canFind(v))
        {
            ret ~= "\\" ~ v.to!size_t
                .to!string(16);
        }
        ret ~= v;
    }
    ret ~= `"`;
    return ret;
}

string serialize(Function.Capture cap)
{
    return cap.elems!"from is2 isArg offset";
}

string serialize(Function.Lookup.Flags flags)
{
    return flags.to!string.serialize;
}

string serialize(Function.Lookup lookup)
{
    return lookup.elems!"byName byPlace flagsByPlace";
}

string serialize(Function.Flags flags)
{
    return flags.to!string.serialize;
}

string serialize(Function func)
{
    return func
        .elems!"capture instrs constants funcs captured self args stackSize stab captab flags names";
}

string serialize(T)(T[] arr)
{
    string str = `[`;
    foreach (n, elem; arr)
    {
        if (n != 0)
        {
            str ~= ", ";
        }
        str ~= elem.serialize;
    }
    str ~= `]`;
    return str;
}

string serialize(K, V)(V[K] assocArray)
{
    string str = `[`;
    size_t n = 0;
    foreach (k, v; assocArray)
    {
        if (n != 0)
        {
            str ~= ", ";
        }
        str ~= `[` ~ k.serialize ~ `, ` ~ v.serialize ~ `]`;
        n += 1;
    }
    str ~= `]`;
    return str;
}

string serialize(T)(T* ptr)
{
    if (ptr is null)
    {
        return `null`;
    }
    return serialize(*ptr);
}

string serialize(Table tab)
{
    string pairs;
    size_t n = 0;
    foreach (key, value; tab)
    {
        if (n != 0)
        {
            pairs ~= `, `;
        }
        pairs ~= "[" ~ key.serialize ~ ", " ~ value.serialize ~ "]";
        n++;
    }
    string meta;
    if (tab.meta.length == 0)
    {
        meta = "null";
    }
    else
    {
        meta = tab.meta.dynamic.serialize;
    }
    return `{"pairs": [` ~ pairs ~ `], "meta": ` ~ meta ~ `}`;
}

Dynamic[] alreadySerialized;
string serialize(Dynamic value)
{
    foreach (index, val; alreadySerialized)
    {
        if (val is value)
        {
            return `{"type": "ref", "ref": ` ~ index.to!string ~ `}`;
        }
    }
    alreadySerialized ~= value;
    scope (exit)
    {
        alreadySerialized.length--;
    }
    final switch (value.type)
    {
    case Dynamic.Type.nil:
        return `{"type": "nil"}`;
    case Dynamic.Type.log:
        return `{"type": "logical", "logical": ` ~ value.log.to!string ~ `}`;
    case Dynamic.Type.sml:
        double n = value.as!double;
        if (isNaN(n) || isInfinity(n))
        {
            return `{"type": "number", "number": "nan"}`;
        }
        return `{"type": "number", "number": ` ~ n.to!string ~ `}`;
    case Dynamic.Type.str:
        return `{"type": "string", "string": ` ~ value.str.serialize ~ `}`;
    case Dynamic.Type.arr:
        return `{"type": "array", "array": ` ~ value.arr.serialize ~ `}`;
    case Dynamic.Type.tab:
        return `{"type": "table", "table": ` ~ value.tab.serialize ~ `}`;
    case Dynamic.Type.fun:
        return `{"type": "function", "function": ` ~ value.fun.fun.mangled.serialize ~ `}`;
    case Dynamic.Type.pro:
        return `{"type": "program", "program": ` ~ value.fun.pro.serialize ~ `}`;
    }
}
