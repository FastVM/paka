module purr.serial.tojson;

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

string serialize(Num)(Num num) if (std.traits.isNumeric!Num)
{
    return '"' ~ num.to!string ~ '"';
}

string serialize(SrcLoc location)
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
    return '"' ~ b.to!string ~ '"';
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

string serialize(Bytecode.Capture cap)
{
    return cap.elems!"from is2 isArg offset";
}

string serialize(Bytecode.Lookup.Flags flags)
{
    return flags.to!string.serialize;
}

string serialize(Bytecode.Lookup lookup)
{
    return lookup.elems!"byName byPlace flagsByPlace";
}

string serialize(Bytecode.Flags flags)
{
    return flags.to!string.serialize;
}

string serialize(Bytecode func)
{
    return func
        .elems!"capture instrs constants funcs captured self args stackSize stab captab flags";
}

string serialize(T)(T[] arr)
{
    string str = `{"length": `;
    str ~= arr.length.to!string.serialize;
    foreach (n, elem; arr)
    {
        str ~= ", ";
        str ~= n.serialize;
        str ~= ": ";
        str ~= elem.serialize;
    }
    str ~= `}`;
    return str;
}

string serialize(Array arr)
{
    string str = `{"length": `;
    str ~= arr.length.to!string.serialize;
    foreach (n, elem; arr)
    {
        str ~= ", ";
        str ~= n.serialize;
        str ~= ": ";
        str ~= elem.serialize;
    }
    str ~= `}`;
    return str;
}

string serialize(T)(T assocArray) if (isAssociativeArray!T)
{
    string str = `{"length": `;
    str ~= assocArray.length.to!string.serialize;
    size_t n = 0;
    foreach (k, v; assocArray)
    {
        str ~= ", ";
        str ~= n.serialize;
        str ~= ": ";
        str ~= `{"key": ` ~ k.serialize ~ `, "value": ` ~ v.serialize ~ `}`;
        n++;
    }
    str ~= `}`;
    return str;
}

string serialize(T)(T* ptr)
{
    if (ptr is null)
    {
        return `{"null": "true"}`;
    }
    return `{"null": "false", "ptr": ` ~ serialize(*ptr) ~ `}`;
}

string serialize(Table tab)
{
    string pairs = `"length": `;
    pairs ~= tab.table.length.serialize;
    size_t n = 0;
    foreach (key, value; tab)
    {
        pairs ~= `, `;
        pairs ~= n.serialize;
        pairs ~= `: `;
        pairs ~= `{"key": ` ~ key.serialize ~ `, "value": ` ~ value.serialize ~ `}`;
        n++;
    }
    string meta;
    return `{` ~ pairs ~ `}`;
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
    switch (value.type)
    {
    default:
        throw new Exception (value.to!string);
    case Dynamic.Type.nil:
        return `{"type": "nil"}`;
    case Dynamic.Type.log:
        return `{"type": "logical", "logical": "` ~ value.log.to!string ~ `"}`;
    case Dynamic.Type.sml:
        return `{"type": "number", "number": ` ~ value.as!double.serialize ~ `}`;
    case Dynamic.Type.sym:
        return `{"type": "symbol", "symbol": ` ~ value.str.serialize ~ `}`;
    case Dynamic.Type.str:
        return `{"type": "string", "string": ` ~ value.str.serialize ~ `}`;
    case Dynamic.Type.tup:
        return `{"type": "tuple", "tuple": ` ~ value.arr.serialize ~ `}`;
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
