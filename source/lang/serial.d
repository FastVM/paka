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
import lang.data.rope;

Dynamic[] jsarr;

Rope!string[4] cs;

LocalTie[] localTies = null;

struct LocalTie
{
    size_t ind1;
    size_t ind2;
    Dynamic* target;
}

void jsInit()
{
    cs[0] = new Rope!string("{");
    cs[1] = new Rope!string(",");
    cs[2] = new Rope!string(":");
    cs[3] = new Rope!string("}");
}

Rope!string jsRope(JSONValue val)
{
    return memoize!jsRopeImpl(val);
}

Rope!string jsRopeImpl(JSONValue val)
{
    if (val.type == JSONType.string)
    {
        return new Rope!string("\"" ~ val.str ~ "\"");
    }
    Rope!string ret = cs[0];
    bool begin = true;
    foreach (i; val.object.byKeyValue)
    {
        if (begin)
        {
            begin = false;
        }
        else
        {
            ret = ret ~ cs[1];
        }
        ret = ret ~ new Rope!string("\"" ~ i.key ~ "\"");
        ret = ret ~ cs[2];
        ret = ret ~ i.value.jsRope;
    }
    ret = ret ~ cs[3];
    return ret;
}

JSONValue saveState()
{
    GC.disable;
    JSONValue ret = JSONValue([
            "localsa": localsa.map!js.array.js,
            "stacka": stacka.map!js.array.js,
            "indexa": indexa.map!js.array.js,
            "deptha": deptha.map!js.array.js,
            "funca": funca.js,
            "base": rootBase.map!js.array.js,
            ]);
    GC.enable;
    return ret;
}

void loadState(JSONValue val)
{
    localTies = null;
    val.object["localsa"].readjs!(typeof(localsa))(&localsa);
    stacka = val.object["stacka"].readjs!(typeof(stacka));
    indexa = val.object["indexa"].readjs!(typeof(indexa));
    deptha = val.object["deptha"].readjs!(typeof(deptha));
    funca = val.object["funca"].readjs!(typeof(funca));
    rootBase = val.object["base"].readjs!(typeof(rootBase));
    foreach (tie; localTies)
    {
        *tie.target = localsa[tie.ind1][tie.ind2];
    }
}

Function readjs(T)(JSONValue val, Function ret = new Function) if (is(T == Function))
{
    ret.capture = val.object["capture"].readjs!(Function.Capture[]);
    ret.instrs = val.object["instrs"].readjs!(Instr[]);
    ret.constants = val.object["constants"].readjs!(Dynamic[]);
    ret.captured = val.object["captured"].readjs!(Dynamic*[]);
    ret.stackSize = val.object["stackSize"].str.to!size_t;
    ret.funcs = val.object["funcs"].readjs!(Function[]);
    ret.self = val.object["self"].readjs!(Dynamic[]);
    ret.stab.byPlace.length = val.object["locc"].readjs!(size_t);
    return ret;
}

Pair readjs(T)(JSONValue val) if (is(T == Pair))
{
    return Pair(val.object["name"].str, val.object["val"].readjs!Dynamic);
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
Function[] abovef;

Dynamic readjs(T)(JSONValue val) if (is(T == Dynamic))
{
    above ~= nil;
    abovef.length++;
    abovef[$ - 1] = null;
    scope (exit)
    {
        abovef.length--;
        above.length--;
    }
    final switch (val.object["type"].str)
    {
    case "ref":
        size_t vst = val.object["value"].str.to!size_t;
        if (abovef[vst]!is null)
        {
            return dynamic(abovef[vst]);
        }
        return above[vst];
    case "nil":
        return nil;
    case "log":
        return dynamic(val.object["value"].str.to!bool);
    case "num":
        return dynamic(val.object["value"].str.to!double);
    case "arr":
        Dynamic ret = dynamic(new Dynamic[val.object["value"].object["length"].str.to!size_t]);
        above[$ - 1] = ret;
        foreach (i, ref v; *ret.value.arr)
        {
            v = val.object["value"].object[i.to!string].readjs!Dynamic;
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
        Function ret = new Function;
        abovef[$ - 1] = ret;
        return dynamic(val.object["value"].readjs!Function(ret));
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
    static if (is(T == Dynamic*))
    {
        if (val.object["type"].str == "stk")
        {
            size_t k1 = val.object["value"].object["level"].str.to!size_t;
            size_t k2 = val.object["value"].object["index"].str.to!size_t;
            size_t ilength = localsa.length;
            localsa.length = max(localsa.length, k1 + 1);
            size_t klength = localsa[k1].length;
            localsa[k1].length = max(localsa[k1].length, k2 + 1);
            Dynamic* ret = &localsa[k1][k2];
            if (ilength != localsa.length || klength != localsa[k1].length)
            {
                *ret = readjs!Dynamic(val.object["literal"]);
            }
            localTies ~= LocalTie(k1, k2, ret);
            return ret;

        }
    }
    if (val.type == JSONType.string && val.str == "null")
    {
        return null;
    }
    return [val.readjs!(PointerTarget!T)].ptr;
}

T readjs(T)(JSONValue val, T* arr = null) if (isArray!T)
{
    if (arr is null)
    {
        arr = [T.init].ptr;
    }
    // T ret = new ElementType!T[val.object["length"].str.to!size_t];
    size_t len = val.object["length"].str.to!size_t;
    (*arr).length = len;
    foreach (i; 0 .. len)
    {
        static if (isArray!(ElementType!T))
        {
            val.object[i.to!string].readjs!(ElementType!T)(&(*arr)[i]);
        }
        else
        {
            (*arr)[i] = val.object[i.to!string].readjs!(ElementType!T);
        }
    }
    return *arr;
}

JSONValue jsp(Dynamic* d)
{
    foreach (n, l; localsa)
    {
        foreach (i; 0 .. l.length)
        {
            if (cast(void*) d == cast(void*)&l[i])
            {
                return JSONValue([
                        "type": JSONValue("stk"),
                        "literal": js(d),
                        "value": JSONValue([
                                "level": n.to!string,
                                "index": i.to!string
                            ])
                        ]);
            }
        }
    }
    return js(*d);
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

JSONValue js(Pair p)
{
    return JSONValue(["name": JSONValue(p.name), "val": p.val.js]);
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

size_t depth;

JSONValue js(Function f)
{
    depth++;
    JSONValue[string] ret;
    ret["capture"] = f.capture.map!js.array.js;
    if (GC.addrOf(f.instrs.ptr) is null)
    {
        assert(0);
    }
    ret["instrs"] = f.instrs.map!js.array.js;
    ret["constants"] = f.constants.map!js.array.js;
    ret["captured"] = f.captured.map!jsp.array.js;
    ret["funcs"] = f.funcs.map!js.array.js;
    ret["stackSize"] = f.stackSize.to!string;
    ret["self"] = f.self.map!js.array.js;
    ret["locc"] = f.stab.byPlace.length.js;
    depth--;
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
    return memoize!jsImpl(d);
}

JSONValue jsImpl(Dynamic d)
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
                "value": JSONValue(d.value.str)
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
