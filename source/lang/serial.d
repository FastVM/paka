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

// Rope!string jsRope(JSONValue val)
// {
//     return memoize!jsRopeImpl(val);
// }

// Rope!string jsRopeImpl(JSONValue val)
// {
//     if (val.type == JSONType.string)
//     {
//         return new Rope!string("\"" ~ val.str ~ "\"");
//     }
//     Rope!string ret = cs[0];
//     bool begin = true;
//     foreach (i; val.object.byKeyValue)
//     {
//         if (begin)
//         {
//             begin = false;
//         }
//         else
//         {
//             ret = ret ~ cs[1];
//         }
//         ret = ret ~ new Rope!string("\"" ~ i.key ~ "\"");
//         ret = ret ~ cs[2];@o
//         ret = ret ~ i.value.jsRope;
//     }
//     ret = ret ~ cs[3];
//     return ret;
// }

JSONValue saveState()
{
    JSONValue ret = JSONValue([
            "localss": localss[0 .. calldepth].map!js.array.js,
            "stacks": stacks[0 .. calldepth].map!js.array.js,
            "indexs": indexs[0 .. calldepth].map!js.array.js,
            "depths": depths[0 .. calldepth].map!js.array.js,
            "funcs": funcs[0 .. calldepth].js,
            "calls": calldepth.js,
            "base": rootBase.map!js.array.js,
            ]);
    return ret;
}

void loadState(JSONValue val)
{
    localTies = null;
    calldepth = val.object["calls"].readjs!size_t;
    val.object["localss"].readjs!(typeof(localss))(&localss);
    localss.length = 1000;
    val.object["stacks"].readjs!(typeof(stacks))(&stacks);
    stacks.length = 1000;
    val.object["indexs"].readjs!(typeof(indexs))(&indexs);
    indexs.length = 1000;
    val.object["depths"].readjs!(typeof(depths))(&depths);
    depths.length = 1000;
    val.object["funcs"].readjs!(typeof(funcs))(&funcs);
    funcs.length = 1000;
    rootBase = val.object["base"].readjs!(typeof(rootBase));
    foreach (tie; localTies)
    {
        *tie.target = localss[tie.ind1][tie.ind2];
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
    ret.env = cast(bool) val.object["env"].readjs!size_t;
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
    above ~= Dynamic.nil;
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
        return Dynamic.nil;
    case "log":
        return dynamic(val.object["value"].str.to!bool);
    case "num":
        return dynamic(val.object["value"].str.to!double);
    case "arr":
        Dynamic ret = dynamic(new Dynamic[val.object["value"].object["length"].str.to!size_t]);
        above[$ - 1] = ret;
        foreach (i, ref v; ret.arr)
        {
            v = val.object["value"].object[i.to!string].readjs!Dynamic;
        }
        return ret;
    case "tab":
        Dynamic ret = dynamic(cast(Table) null);
        above[$ - 1] = ret;
        foreach (i; val.object["value"].object.byValue)
        {
            ret.tab[i.object["key"].readjs!Dynamic] = i.object["value"].readjs!Dynamic;
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
            ret = Dynamic.nil;
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
            size_t ilength = calldepth;
            calldepth = max(calldepth, k1 + 1);
            size_t klength = localss[k1].length;
            localss[k1].length = max(localss[k1].length, k2 + 1);
            Dynamic* ret = &localss[k1][k2];
            if (ilength != localss.length || klength != localss[k1].length)
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
    foreach (n, l; localss[0 .. calldepth])
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
    // writeln(d.length, ": ", d.ptr);
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
    ret["instrs"] = f.instrs.map!js.array.js;
    ret["constants"] = f.constants.map!js.array.js;
    ret["funcs"] = f.funcs.map!js.array.js;
    ret["stackSize"] = f.stackSize.to!string;
    ret["self"] = f.self.map!js.array.js;
    ret["locc"] = f.stab.byPlace.length.js;
    ret["env"] = (cast(size_t)(f.env)).js;
    ret["captured"] = f.captured.map!jsp.array.js;
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
    switch (d.type)
    {
    default:
        assert(0);
    case Dynamic.Type.nil:
        return JSONValue(["type": JSONValue("nil")]);
    case Dynamic.Type.log:
        return JSONValue([
                "type": JSONValue("log"),
                "value": JSONValue(d.log.to!string)
                ]);
    case Dynamic.Type.num:
        return JSONValue([
                "type": JSONValue("num"),
                "value": JSONValue(d.num.to!string)
                ]);
    case Dynamic.Type.str:
        return JSONValue(["type": JSONValue("str"), "value": JSONValue(d.str)]);
    case Dynamic.Type.arr:
        return JSONValue(["type": JSONValue("arr"), "value": d.arr.js]);
    case Dynamic.Type.tab:
        JSONValue[string] ret;
        size_t i = 0;
        foreach (v; d.tab.byKeyValue)
        {
            ret[i.to!string] = JSONValue(["key": v.key.js, "value": v.value.js]);
            i++;
        }
        return JSONValue(["type": JSONValue("tab"), "value": JSONValue(ret)]);
    case Dynamic.Type.fun:
        return JSONValue([
                "type": JSONValue("fun"),
                "value": JSONValue(serialLookup[d.fun.fun])
                ]);
    case Dynamic.Type.pro:
        return JSONValue(["type": JSONValue("pro"), "value": d.fun.pro.js]);
    case Dynamic.Type.end:
        return JSONValue(["type": "end"]);
    case Dynamic.Type.dat:
        JSONValue[string] ret;
        ret["length"] = JSONValue(d.arr.length.to!string);
        foreach (i, v; d.arr)
        {
            ret[i.to!string] = v.js;
        }
        return JSONValue(["type": JSONValue("dat"), "value": JSONValue(ret)]);
    case Dynamic.Type.pac:
        if (d.arr is null)
        {
            return JSONValue([
                    "type": JSONValue("pac"),
                    "value": JSONValue("null")
                    ]);
        }
        JSONValue[string] ret;
        ret["length"] = JSONValue(d.arr.length.to!string);
        foreach (i, v; d.arr)
        {
            ret[i.to!string] = v.js;
        }
        return JSONValue(["type": JSONValue("pac"), "value": JSONValue(ret)]);
    }
}
