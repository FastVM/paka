module purr.serial.fromjson;

import purr.io;
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
import purr.data.rope;
import purr.plugin.syms;
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
    case "tuple":
        return Dynamic.Type.tup;
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
    return json.str.to!bool;
}

Num deserialize(Num)(Json json) if (std.traits.isNumeric!Num)
{
    return json.str.to!Num;
}

string deserialize(T)(Json json) if (is(T == string))
{
    return json.str;
}
Array deserialize(Array)(Json json)
        if (isArray!Array && !isSomeChar!(ElementType!Array))
{
    Array ret = new Array(json["length"].deserialize!size_t);
    foreach (key; 0..ret.length)
    {
        ret[key] = json[key.to!string].deserialize!(ElementType!Array);
    }
    return ret;
}

AssocArray deserialize(AssocArray)(Json json) if (isAssociativeArray!AssocArray)
{
    AssocArray ret;
    foreach (n; 0..json["length"].deserialize!size_t)
    {
        Json kv = json[n.to!string];
        ret[kv["key"].deserialize!(KeyType!AssocArray)] = kv["value"].deserialize!(ValueType!AssocArray);
    }
    return ret;
}

Pointer deserialize(Pointer)(Json json)
        if (isPointer!Pointer && !is(Pointer == void*) && !std.traits.isFunctionPointer!Pointer)
{
    bool isNull = json.object["null"].str.to!bool;
    if (isNull)
    {
        return null;
    }
    else
    {
        return new PointerTarget!Pointer(json.object["ptr"].deserialize!(PointerTarget!Pointer));
    }
}

Table deserialize(T : Table)(Json json)
{
    Mapping mapping = emptyMapping;
    foreach (n; 0..json["length"].deserialize!size_t)
    {
        Json kv = json[n.to!string];
        mapping[kv["key"].deserialize!Dynamic] = kv["value"].deserialize!Dynamic;
    }
    return new Table(mapping);
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

T deserialize(T)(Json json) if (is(T == Dynamic function(Args)))
{
    return json.str.getNative;
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
    Function retn = json.elems!(
            "capture instrs constants funcs captured self args stackSize stab captab flags",
            T);
    return retn;
}

Pair deserialize(T : Pair)(Json json)
{
    return json.elems!("name val", T);
}

ReturnType!func cache(alias func)(ParameterTypeTuple!func args)
{
    alias Args = ParameterTypeTuple!func;
    alias Ret = ReturnType!func;
    Ret result = func(args);
    return result;
}

alias deserializeCached = cache!(deserialize!(Dynamic));

Dynamic[] above;
Dynamic deserialize(T : Dynamic)(Json json)
{
    if (json["type"].str == "ref")
    {
        return above[json["ref"].integer];
        // throw new Exception("you have found a bug in libpaka_serial.so: cannot serialize self referential objects");
    }
    above ~= Dynamic.nil;
    scope (exit)
    {
        above.length--;
    }
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
    case Dynamic.Type.sym:
        return Dynamic.sym(json["symbol"].deserialize!string);
    case Dynamic.Type.tup:
        above[$ - 1] = Array.init.dynamic;
        Dynamic[] got = json["tuple"].deserialize!(Array);
        foreach (elem; got)
        {
            got ~= elem;
        }
        above[$-1].value.arr = got.ptr;
        above[$-1].len = cast(uint) got.length;
        return above[$ - 1];
    case Dynamic.Type.arr:
        above[$ - 1] = Array.init.dynamic;
        Dynamic[] got = json["array"].deserialize!(Array);
        above[$-1].value.arr = got.ptr;
        above[$-1].len = cast(uint) got.length;
        return above[$ - 1];
    case Dynamic.Type.tab:
        Table child = Table.empty;
        above[$ - 1] = child.dynamic;
        Table got = json["table"].deserialize!(Table);
        child.table = got.table;
        return child.dynamic;
    case Dynamic.Type.fun:
        Dynamic function(Args) res = json["function"].deserialize!(Dynamic function(Args));
        return Fun(res, json["function"].deserialize!string).dynamic;
    case Dynamic.Type.pro:
        Function child = new Function;
        above[$ - 1] = child.dynamic;
        Function got = json["program"].deserialize!(Function);
        child.copy(got);
        return child.dynamic;
    }
}
