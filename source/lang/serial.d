module lang.serial;

import std.json;
import std.conv;
import std.algorithm;
import std.array;
import std.range;
import std.traits;
import std.stdio;
import std.functional;
import core.memory;
import lang.vm;
import lang.base;
import lang.bytecode;
import lang.dynamic;

Dynamic[] jsarr;

JSONValue saveState()
{
    return JSONValue([
            "stacka": stacka.js,
            "localsa": localsa.js,
            "indexa": indexa.map!js.array.js,
            "deptha": deptha.map!js.array.js,
            "funca": funca.js,
            ]);
}

void loadState(JSONValue val)
{
    stacka = val.object["stacka"].readjs!(typeof(stacka));
    localsa = val.object["localsa"].readjs!(typeof(localsa));
    indexa = val.object["indexa"].readjs!(typeof(indexa));
    deptha = val.object["deptha"].readjs!(typeof(deptha));
    funca = val.object["funca"].readjs!(typeof(funca));
    stack[depth - 1] = lfalse;
}

Function readjs(T)(JSONValue val) if (is(T == Function))
{
    Function ret = new Function;
    ret.capture = val.object["capture"].readjs!(Function.Capture[]);
    ret.instrs = val.object["instrs"].readjs!(Instr[]);
    ret.constants = val.object["constants"].readjs!(Dynamic[]);
    ret.captured = val.object["captured"].readjs!(Dynamic*[]);
    ret.stackSize = val.object["stackSize"].str.to!size_t;
    ret.self = val.object["self"].readjs!(Dynamic[]);
    return ret;
}

Function.Capture readjs(T)(JSONValue val) if (is(T == Function.Capture))
{
    return Function.Capture(val.object["from"].str.to!ushort, val.object["is2"].str.to!bool);
}

Instr readjs(T)(JSONValue val) if (is(T == Instr))
{
    return Instr(val.object["op"].str.to!Opcode, val.object["value"].str.to!ushort);
}

size_t readjs(T)(JSONValue val) if (is(T == size_t))
{
    return val.str.to!size_t;
}

Dynamic[] above;

Dynamic readjs(T)(JSONValue val) if (is(T == Dynamic))
{
    above ~= nil;
    scope (exit)
    {
        above.length--;
    }
    final switch (val.object["type"].str)
    {
    case "ref":
        return above[val.object["value"].str.to!size_t];
    case "nil":
        return nil;
    case "log":
        return dynamic(val.object["value"].str.to!bool);
    case "num":
        return dynamic(val.object["value"].str.to!double);
    case "arr":
        Dynamic ret = dynamic(new Dynamic[val.object["length"].str.to!size_t]);
        above[$ - 1] = ret;
        foreach (i, ref v; *ret.value.arr)
        {
            v = val.object[i.to!string].readjs!Dynamic;
        }
        return ret;
    case "tab":
        Dynamic ret = dynamic(cast(Table) null);
        above[$ - 1] = ret;
        foreach (i; val.object["value"].object.byValue)
        {
            (*ret.value.tab)[i.object["key"].readjs!Dynamic] = i.object["value"].readjs!Dynamic;
        }
        return ret;
    case "str":
        return dynamic(val.object["value"].str);
    case "fun":
        return dynamic(rootFuncs[val.object["value"].str]);
    case "pro":
        return dynamic(val.object["value"].readjs!Function);
    case "end":
        return dynamic(Dynamic.Type.end);
    case "dat":
        Dynamic ret = dynamic(val.object["value"].readjs!(Dynamic[]));
        ret.type = Dynamic.Type.arr;
        return ret;
    case "pac":
        Dynamic ret = void;
        if (val.object["value"].type == JSONType.string)
        {
            ret = nil;
        }
        else
        {
            ret = dynamic(val.object["value"].readjs!(Dynamic[]));
        }
        ret.type = Dynamic.Type.pac;
        return ret;
    }
}

T readjs(T)(JSONValue val) if (isPointer!T)
{
    if (val.type == JSONType.string && val.str == "null")
    {
        return null;
    }
    return [val.readjs!(PointerTarget!T)].ptr;
}

T readjs(T)(JSONValue val) if (isArray!T)
{
    T ret = new ElementType!T[val.object["length"].str.to!size_t];
    foreach (i, ref v; ret)
    {
        v = val.object[i.to!string].readjs!(ElementType!T);
    }
    return ret;
}

JSONValue js(T)(T[] d)
{
    JSONValue[string] ret;
    ret["length"] = JSONValue(d.length.to!string);
    foreach (i, v; d)
    {
        ret[i.to!string] = v.js;
    }
    return JSONValue(ret);
}

JSONValue js(size_t v)
{
    return JSONValue(v.to!string);
}

JSONValue js(JSONValue d)
{
    return d;
}

JSONValue js(Function.Capture c)
{
    return JSONValue(["from": c.from.to!string, "is2": c.is2.to!string]);
}

JSONValue js(Instr inst)
{
    return JSONValue(["op": inst.op.to!string, "value": inst.value.to!string]);
}

JSONValue js(Function f)
{
    JSONValue[string] ret;
    ret["capture"] = f.capture.map!js.array.js;
    ret["instrs"] = f.instrs.map!js.array.js;
    ret["constants"] = f.constants.map!js.array.js;
    ret["funcs"] = f.funcs.map!js.array.js;
    ret["captured"] = f.captured.map!js.array.js;
    ret["stackSize"] = f.stackSize.to!string;
    ret["self"] = f.self.map!js.array.js;
    return JSONValue(ret);
}

JSONValue js(T)(T* v)
{
    if (v is null)
    {
        return JSONValue("null");
    }
    return js(*v);
}

JSONValue js(Dynamic d)
{
    foreach (i, v; jsarr)
    {
        if (v == d)
        {
            return JSONValue(["type": "ref", "value": i.to!string]);
        }
    }
    jsarr ~= d;
    scope (exit)
    {
        jsarr.length--;
    }
    final switch (d.type)
    {
    case Dynamic.Type.nil:
        return JSONValue(["type": JSONValue("nil")]);
    case Dynamic.Type.log:
        return JSONValue([
                "type": JSONValue("log"),
                "value": JSONValue(d.value.log.to!string)
                ]);
    case Dynamic.Type.num:
        return JSONValue([
                "type": JSONValue("num"),
                "value": JSONValue(d.value.num.to!string)
                ]);
    case Dynamic.Type.str:
        return JSONValue([
                "type": JSONValue("str"),
                "value": JSONValue(*d.value.str)
                ]);
    case Dynamic.Type.arr:
        return JSONValue(["type": JSONValue("arr"), "value": js(*d.value.arr)]);
    case Dynamic.Type.tab:
        JSONValue[string] ret;
        size_t i = 0;
        foreach (v; d.value.tab.byKeyValue)
        {
            ret[i.to!string] = JSONValue(["key": v.key.js, "value": v.value.js]);
            i++;
        }
        return JSONValue(["type": JSONValue("tab"), "value": JSONValue(ret)]);
    case Dynamic.Type.fun:
        return JSONValue([
                "type": JSONValue("fun"),
                "value": JSONValue(serialLookup[d.value.fun.fun])
                ]);
    case Dynamic.Type.pro:
        return JSONValue(["type": JSONValue("pro"), "value": d.value.fun.pro.js]);
    case Dynamic.Type.end:
        return JSONValue(["type": "end"]);
    case Dynamic.Type.dat:
        JSONValue[string] ret;
        ret["length"] = JSONValue(d.value.arr.length.to!string);
        foreach (i, v; *d.value.arr)
        {
            ret[i.to!string] = v.js;
        }
        return JSONValue(["type": JSONValue("dat"), "value": JSONValue(ret)]);
    case Dynamic.Type.pac:
        if (d.value.arr is null)
        {
            return JSONValue([
                    "type": JSONValue("pac"),
                    "value": JSONValue("null")
                    ]);
        }
        JSONValue[string] ret;
        ret["length"] = JSONValue(d.value.arr.length.to!string);
        foreach (i, v; *d.value.arr)
        {
            ret[i.to!string] = v.js;
        }
        return JSONValue(["type": JSONValue("pac"), "value": JSONValue(ret)]);
    }
}
