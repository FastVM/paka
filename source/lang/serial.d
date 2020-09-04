module lang.serial;

import std.conv;
import std.algorithm;
import std.array;
import std.range;
import std.traits;
import std.stdio;
import std.functional;
import core.memory;
import lang.vm;
import lang.json;
import lang.base;
import lang.bytecode;
import lang.dynamic;
import lang.data.array;

// enum string gcOffFor = `
//     GC.disable();
//     scope(exit) {GC.enable();}
// `;

SafeArray!Dynamic jsarr;

LocalTie[] localTies = null;

struct LocalTie
{
    size_t ind1;
    size_t ind2;
    Dynamic* target;
}

SerialValue saveState(bool repl = false)()
{
    SerialValue jslocals = localss[0 .. calldepth].map!js.array.js;
    SerialValue jsstacks = stacks[0 .. calldepth].map!js.array.js;
    SerialValue jsindexs = indexs[0 .. calldepth].map!js.array.js;
    SerialValue jsdepths = depths[0 .. calldepth].map!js.array.js;
    SerialValue jsfuncs = funcs[0 .. calldepth].js;
    SerialValue jsbase = rootBase.map!js.array.js;
    SerialValue jscalls = calldepth.js;
    SerialValue[string] data = [
        "localss" : jslocals, "stacks" : jsstacks, "indexs" : jsindexs,
        "depths" : jsdepths, "funcs" : jsfuncs, "base" : jsbase,
        "calls" : jscalls, 
    ];
    SerialValue ret = SerialValue(data);
    return ret;
}

void loadState(bool repl = false)(SerialValue val)
{
    localTies = null;
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
    val.object["base"].readjs!(typeof(rootBase))(&rootBase);
    calldepth = val.object["calls"].readjs!(size_t);
    foreach (tie; localTies)
    {
        *tie.target = localss[tie.ind1][tie.ind2];
    }
}

Function readjs(T)(SerialValue val, Function ret = new Function) if (is(T == Function))
{
    ret.capture = val.object["capture"].readjs!(Function.Capture[]);
    ret.instrs = val.object["instrs"].readjs!(Instr[]);
    ret.constants = val.object["constants"].readjs!(SafeArray!Dynamic);
    ret.captured = val.object["captured"].readjs!(Dynamic*[]);
    ret.stackSize = val.object["stackSize"].str.to!size_t;
    ret.funcs = val.object["funcs"].readjs!(Function[]);
    ret.self = val.object["self"].readjs!(SafeArray!Dynamic);
    ret.stab.byPlace.length = val.object["locc"].readjs!(size_t);
    ret.env = cast(bool) val.object["env"].readjs!size_t;
    return ret;
}

Pair readjs(T)(SerialValue val) if (is(T == Pair))
{
    return Pair(val.object["name"].str, val.object["val"].readjs!Dynamic);
}

Function.Capture readjs(T)(SerialValue val) if (is(T == Function.Capture))
{
    return Function.Capture(val.object["from"].str.to!ushort, val.object["is2"].str.to!bool);
}

Instr readjs(T)(SerialValue val) if (is(T == Instr))
{
    return Instr(val.object["op"].str.to!Opcode, val.object["value"].str.to!ushort);
}

size_t readjs(T)(SerialValue val) if (is(T == size_t))
{
    return val.str.to!size_t;
}

SafeArray!Dynamic above;
Function[] abovef;

Dynamic readjs(T)(SerialValue val) if (is(T == Dynamic))
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
        Dynamic ret = dynamic(val.object["value"].readjs!(SafeArray!Dynamic));
        ret.type = Dynamic.Type.arr;
        return ret;
    case "pac":
        Dynamic ret = void;
        if (val.object["value"].type == SerialType.string)
        {
            ret = Dynamic.nil;
        }
        else
        {
            ret = dynamic(val.object["value"].readjs!(SafeArray!Dynamic));
        }
        ret.type = Dynamic.Type.pac;
        return ret;
    }
}

T readjs(T)(SerialValue val) if (isPointer!T)
{
    static if (is(T == Dynamic*))
    {
        if (val.object["type"].str == "stk")
        {
            size_t k1 = val.object["value"].object["level"].str.to!size_t;
            size_t k2 = val.object["value"].object["index"].str.to!size_t;
            size_t ilength = calldepth;
            if (k1 > calldepth)
            {
                return [val.object["literal"].readjs!Dynamic].ptr;
            }
            size_t klength = localss[k1].length;
            localss[k1].length = max(localss[k1].length, k2 + 1);
            Dynamic* ret = &localss[k1][k2];
            if (ilength != localss.length || klength != localss[k1].length)
            {
                *ret = val.object["literal"].readjs!Dynamic;
            }
            localTies ~= LocalTie(k1, k2, ret);
            return ret;

        }
    }
    if (val.type == SerialType.string && val.str == "null")
    {
        return null;
    }
    return [val.readjs!(PointerTarget!T)].ptr;
}

T readjs(T)(SerialValue val, T* arr = null)
        if (isArray!T || is(T == SafeArray!Dynamic))
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
        static if (is(ElementType!T == SafeArray!Dynamic))
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

SerialValue jsp(Dynamic* d)
{
    foreach (n, l; localss[0 .. calldepth])
    {
        foreach (i; 0 .. l.length)
        {
            if (cast(void*) d == cast(void*)&l[i])
            {
                return SerialValue([
                        "type": SerialValue("stk"),
                        "literal": js(d),
                        "value": SerialValue([
                                "level": n.to!string,
                                "index": i.to!string
                            ])
                        ]);
            }
        }
    }
    return js(*d);
}

SerialValue js(T)(T[] d)
{
    SerialValue[string] ret;
    ret["length"] = SerialValue(d.length.to!string);
    foreach (i, v; d)
    {
        ret[i.to!string] = v.js;
    }
    return SerialValue(ret);
}

SerialValue js(Pair p)
{
    return SerialValue(["name": SerialValue(p.name), "val": p.val.js]);
}

SerialValue js(size_t v)
{
    return SerialValue(v.to!string);
}

SerialValue js(SerialValue d)
{
    return d;
}

SerialValue js(Function.Capture c)
{
    return SerialValue(["from": c.from.to!string, "is2": c.is2.to!string]);
}

SerialValue js(Instr inst)
{
    return SerialValue(["op": inst.op.to!string, "value": inst.value.to!string]);
}

size_t depth;

SerialValue js(Function f)
{
    depth++;
    SerialValue[string] ret;
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
    return SerialValue(ret);
}

SerialValue js(T)(T* v)
{
    if (v is null)
    {
        return SerialValue("null");
    }
    return js(*v);
}

SerialValue js(Dynamic d)
{
    foreach (i, v; jsarr)
    {
        if (v == d)
        {
            return SerialValue(["type": "ref", "value": i.to!string]);
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
        return SerialValue(["type": SerialValue("nil")]);
    case Dynamic.Type.log:
        return SerialValue([
                "type": SerialValue("log"),
                "value": SerialValue(d.log.to!string)
                ]);
    case Dynamic.Type.num:
        return SerialValue([
                "type": SerialValue("num"),
                "value": SerialValue(d.num.to!string)
                ]);
    case Dynamic.Type.str:
        return SerialValue(["type": SerialValue("str"), "value": SerialValue(d.str)]);
    case Dynamic.Type.arr:
        return SerialValue(["type": SerialValue("arr"), "value": d.arr.js]);
    case Dynamic.Type.tab:
        SerialValue[string] ret;
        size_t i = 0;
        foreach (v; d.tab.byKeyValue)
        {
            ret[i.to!string] = SerialValue(["key": v.key.js, "value": v.value.js]);
            i++;
        }
        return SerialValue(["type": SerialValue("tab"), "value": SerialValue(ret)]);
    case Dynamic.Type.fun:
        return SerialValue([
                "type": SerialValue("fun"),
                "value": SerialValue(serialLookup[d])
                ]);
    case Dynamic.Type.pro:
        return SerialValue(["type": SerialValue("pro"), "value": d.fun.pro.js]);
    case Dynamic.Type.end:
        return SerialValue(["type": "end"]);
    case Dynamic.Type.dat:
        SerialValue[string] ret;
        ret["length"] = SerialValue(d.arr.length.to!string);
        foreach (i, v; d.arr)
        {
            ret[i.to!string] = v.js;
        }
        return SerialValue(["type": SerialValue("dat"), "value": SerialValue(ret)]);
    case Dynamic.Type.pac:
        if (d.arr is null)
        {
            return SerialValue([
                    "type": SerialValue("pac"),
                    "value": SerialValue("null")
                    ]);
        }
        SerialValue[string] ret;
        ret["length"] = SerialValue(d.arr.length.to!string);
        foreach (i, v; d.arr)
        {
            ret[i.to!string] = v.js;
        }
        return SerialValue(["type": SerialValue("pac"), "value": SerialValue(ret)]);
    }
}
