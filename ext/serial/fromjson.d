module serial.fromjson;

import std.stdio;
import std.conv;
import std.format;
import std.algorithm;
import std.traits;
import std.range;
import std.array;
import purr.base;
import purr.srcloc;
import purr.dynamic;
import purr.bytecode;
import purr.plugin.plugin;
import purr.plugin.plugins;
import std.json;

alias Json = JSONValue;

Dynamic.Type dtype(Json json)
{
    final switch (json["type"].str)
    {
    case "nil":
        return Dynamic.Type.nil;
    case "logical":
        return Dynamic.Type.log;
    case "number":
        return Dynamic.Type.sml;
    case "string":
        return Dynamic.Type.str;
    case "array":
        return Dynamic.Type.arr;
    case "table":
        return Dynamic.Type.tab;
    case "function":
        return Dynamic.Type.fun;
    case "program":
        return Dynamic.Type.pro;
    }
}

bool deserialize(T)(Json json) if (is(T == bool))
{
    return json.boolean;
}

double deserialize(T)(Json json) if (is(T == double))
{
    if (json.type == JSONType.float_)
    {
        return json.floating;
    }
    else if (json.type == JSONType.integer)
    {
        return cast(double) json.integer;
    }
    else
    {
        throw new Exception("bad json");
    }
}

string deserialize(T)(Json json) if (is(T == string))
{
    return json.str;
}

Int deserialize(Int)(Json json)
        if (is(Int == int) || is(Int == uint) || is(Int == short) || is(Int == ushort) || is(Int == byte) || is(Int == ubyte))
{
    return cast(Int) json.integer;
}

Int deserialize(Int)(Json json)
        if (is(Int == long) || is(Int == ulong))
{
    return cast(Int) json.integer;
}

Array deserialize(Array)(Json json) if (isArray!Array && !isSomeChar!(ElementType!Array))
{
    Array ret;
    foreach (elem; json.array)
    {
        ret ~= elem.deserialize!(ElementType!Array);
    }
    return ret;
}

AssocArray deserialize(AssocArray)(Json json) if (isAssociativeArray!AssocArray)
{
    AssocArray ret;
    foreach (elem; json.array)
    {
        ret[elem.array[0].deserialize!(KeyType!AssocArray)] = elem.array[1].deserialize!(ValueType!AssocArray);
    }
    return ret;
}

Pointer deserialize(Pointer)(Json json) if (isPointer!Pointer && !is(Pointer == void*))
{
    if (json.type == JSONType.null_)
    {
        return null;
    }
    else
    {
        return new PointerTarget!Pointer(json.deserialize!(PointerTarget!Pointer));
    }
}

Table deserialize(T : Table)(Json json)
{
    if (json.type == JSONType.null_)
    {
        return new Table(emptyMapping);
    }
    else
    {
        Mapping mapping = emptyMapping;
        Table meta = json["meta"].deserialize!Table;
        foreach (kv; json["pairs"].array)
        {
            mapping[kv.array[0].deserialize!Dynamic] = kv.array[1].deserialize!Dynamic;
        }
        return new Table(mapping, meta);
    }
}

T elem(string name, T)(Json json)
{
    return json[name].deserialize!T;
}

T elems(string names, T)(Json json) if (is(T == struct))
{
    T ret = T.init;
    static foreach (index, name; names.splitter(" ").array)
    {
        mixin("ret." ~ name) = json.elem!(name, typeof(mixin("ret." ~ name)));
    }
    return ret;
}

T elems(string names, T)(Json json) if (is(T == class))
{
    T ret = cast(T) Object.factory(fullyQualifiedName!T);
    static foreach (index, name; names.splitter(" ").array)
    {
        mixin("ret." ~ name) = json.elem!(name, typeof(mixin("ret." ~ name)));
    }
    return ret;
}

Location deserialize(T : Location)(Json json)
{
    return json.elems!("line column file", T);
}

Span deserialize(T : Span)(Json json)
{
    return json.elems!("first last", T);
}

Function.Capture deserialize(T : Function.Capture)(Json json)
{
    return json.elems!("from is2 isArg offset", T);
}

Function.Lookup.Flags deserialize(T : Function.Lookup.Flags)(Json json)
{
    return json.str.to!T;
}

Function.Lookup deserialize(T : Function.Lookup)(Json json)
{
    return json.elems!("byName byPlace flagsByPlace", T);
}

Function.Flags deserialize(T : Function.Flags)(Json json)
{
    return json.str.to!T;
}

Function deserialize(T : Function)(Json json)
{
    return json.elems!(
            "capture instrs spans constants funcs captured self args stackSize stab captab flags names",
            T);
}

Dynamic deserialize(T : Dynamic)(Json json)
{
    final switch (json.dtype)
    {
    case Dynamic.Type.nil:
        return Dynamic.nil;
    case Dynamic.Type.log:
        return json["logical"].deserialize!bool.dynamic;
    case Dynamic.Type.sml:
        return json["number"].deserialize!double.dynamic;
    case Dynamic.Type.str:
        return json["string"].deserialize!string.dynamic;
    case Dynamic.Type.arr:
        return json["array"].deserialize!(Dynamic[]).dynamic;
    case Dynamic.Type.tab:
        return json["table"].deserialize!(Table).dynamic;
    case Dynamic.Type.fun:
        assert(false);
    case Dynamic.Type.pro:
        return json["program"].deserialize!(Function).dynamic;
    }
}
