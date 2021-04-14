module purr.base;

import std.algorithm;
import purr.io;
import std.conv;
import std.traits;
import purr.dynamic;
import purr.bytecode;
import purr.plugin.syms;
import purr.plugin.plugins;

Pair FunctionPair(alias func)(string name)
{
    syms[func.mangleof] = &func;
    Fun fun = Fun(&func);
    fun.names ~= name.dynamic;
    fun.mangled = func.mangleof;
    return Pair(name, fun);
}

struct Pair
{
    string name;
    Dynamic val;
    this(T)(string n, T v) 
    {
        name = n;
        val = v.dynamic;
    }
}

Pair[][] rootBases;

ref Pair[] rootBase(size_t index = rootBases.length - 1)
{
    assert(index < rootBases.length);
    return rootBases[index];
}

size_t enterCtx()
{
    rootBases ~= pluginLib;
    return rootBases.length - 1;
}

void exitCtx()
{
    rootBases.length--;
}

string[] definedLibs;
string[] defined;
void addLib(ref Pair[] pairs, string name, Pair[] lib)
{
    Mapping dyn = emptyMapping;
    foreach (entry; lib)
    {
        if (!entry.name.canFind('.'))
        {
            string newName = name ~ "." ~ entry.name;
            defined ~= newName;
            dyn[dynamic(entry.name)] = entry.val;
        }
    }
    definedLibs ~= name;
    pairs ~= Pair(name, dyn);
}

// TODO: return Function.Lookup instead of empty function
Function.Lookup baseFunctionLookup(size_t ctx)
{
    Function.Lookup stab = Function.Lookup(null, null);
    foreach (name; ctx.rootBase)
    {
        stab.define(name.name);
    }
    return stab;
}

Dynamic[] loadBase(size_t ctx)
{
    Dynamic[] ret;
    foreach (i; ctx.rootBase)
    {
        ret ~= i.val;
    }
    return ret;
}

Function baseFunction(size_t ctx = rootBases.length-1)
{
    Function func = new Function;
    func.stab = ctx.baseFunctionLookup;
    func.captured = ctx.loadBase;
    return func;
}

version(unittest)
{
    enum string[] libnames = ["varunit", "unttest", "_unit_test", "_purr.unittest.lib", "", "123", "\x04\x09\x08\x04", "\"\""];
    enum string[] varnames = ["i have spaces", "\0", "()", "nil", ".", "args", "@if"];
    enum string voidname = "void";

    Dynamic libunitvoid(Args args)
    {
        return args.dynamic;
    }

    Pair[] libunit()
    {
        return [
            FunctionPair!libunitvoid("void"),
            Pair("value", 10),
        ];
    }
}

unittest
{
    size_t ctx = enterCtx;
    assert(rootBases.length == 1, "no base should exist before construction");
    assert(ctx.rootBase.length == 0, "no base values should be defined");
    exitCtx;
}

unittest
{
    size_t ctx = enterCtx;
    foreach (libname; libnames)
    {
        ctx.rootBase.addLib(libname, libunit);
    }
    assert(ctx.rootBase.length == libnames.length, "addlib should add ctx single base value for libs");
    exitCtx;
}

unittest
{
    
    size_t ctx = enterCtx;
    foreach (libname; libnames)
    {
        ctx.rootBase.addLib(libname, libunit);
        ctx.rootBase ~= Pair(libname, Dynamic.nil);
    }
    Function.Lookup stab = ctx.baseFunctionLookup;
    foreach (libname; libnames)
    {
        assert(libname in stab.byName, libname ~ " should have been defined by addLib");
        size_t index = stab.byName[libname];
        assert(stab.byPlace[index] == libname, "symbol table should define a symbol once exactly");
    }
    exitCtx;
}

unittest
{
    size_t ctx = enterCtx;
    Dynamic orig = dynamic(&libunitvoid);
    ctx.rootBase ~= Pair(voidname, &libunitvoid);
    Function func = ctx.baseFunction;
    func.captured = ctx.loadBase;
    size_t index = func.stab[voidname];
    Dynamic var = *func.captured[index];
    assert(var == orig, "symbol table should work");
    foreach (i; 0..3)
    {
        assert(var(new Dynamic[i]) == orig(new Dynamic[i]), "symbol table should work for calls");
    }
    exitCtx;
}

unittest
{
    import std.random;
    import std.conv;
    size_t ctx = enterCtx;
    Dynamic[string] vars;
    Random rand = Random(0);
    foreach (varname; varnames)
    {
        double dval = uniform!"()"(0.0, 1.0, rand);
        vars[varname] = dval.dynamic;
        ctx.rootBase ~= Pair(varname, dval);
    }
    ctx.rootBase ~= Pair(voidname, &libunitvoid);
    Function func = ctx.baseFunction;
    func.captured = ctx.loadBase;
    foreach (varname; varnames)
    {
        size_t index = func.stab[varname];
        Dynamic var = *func.captured[index];
        assert(var == vars[varname], "var " ~ varname ~ " should be " ~ var.to!string ~ " not " ~ vars[varname].dynamic.to!string);
    }
}
