module purr.native.lib;

public import purr.dynamic;
public import purr.plugin.loader;
public import purr.plugin.plugin;
public import std.stdio;
public import std.conv;
public import std.getopt;
public import core.stdc.stdlib;
public import core.sys.posix.dlfcn;
public import core.runtime;

Lib lib;
bool echo = false;

class Lib
{
    Dynamic[string] vars;
    Dynamic getVar()(string name)
    {
        return vars[name];
    }
}

void maybeEcho(Dynamic dyn)
{
    if (echo && dyn.type != Dynamic.type.nil)
    {
        writeln(dyn);
    }
}

void argParse(string[] args)
{
    string[] loads;
    auto info = getopt(args, "echo", &echo, "load", &loads);    if (info.helpWanted)
    {
        defaultGetoptPrinter("Help for 9c language.", info.options);
        exit(1);
    }
    lib = new Lib;
    foreach (i; loads)
    {
        Plugin plugin = loadLang(i);
        foreach (pair; plugin.libs)
        {
            lib.vars[pair.name] = pair.val;
        }
    }
}

extern(C) void quick_exit( int exit_code );

void exitNow()
{
    quick_exit(0);
}

Dynamic indexOp(Dynamic lhs, Dynamic rhs)
{
    switch (lhs.type)
    {
    case Dynamic.Type.arr:
        return lhs.arr[rhs.as!size_t];
    case Dynamic.Type.tab:
        return lhs.tab[rhs];
    default:
        throw new Exception("error: cannot store at index on a " ~ lhs.type.to!string);
    }
}

Dynamic catOp(Dynamic lhs, Dynamic rhs)
{
    return lhs ~ rhs;
}

Dynamic addOp(Dynamic lhs, Dynamic rhs)
{
    return lhs + rhs;
}

Dynamic subOp(Dynamic lhs, Dynamic rhs)
{
    return lhs - rhs;
}

Dynamic modOp(Dynamic lhs, Dynamic rhs)
{
    return lhs % rhs;
}

Dynamic mulOp(Dynamic lhs, Dynamic rhs)
{
    return lhs * rhs;
}

Dynamic divOp(Dynamic lhs, Dynamic rhs)
{
    return lhs / rhs;
}

Dynamic negOp(Dynamic rhs)
{
    return -rhs;
}

Dynamic ltOp(Dynamic lhs, Dynamic rhs)
{
    return dynamic(lhs < rhs);
}

Dynamic gtOp(Dynamic lhs, Dynamic rhs)
{
    return dynamic(lhs > rhs);
}

Dynamic lteOp(Dynamic lhs, Dynamic rhs)
{
    return dynamic(lhs <= rhs);
}

Dynamic gteOp(Dynamic lhs, Dynamic rhs)
{
    return dynamic(lhs >= rhs);
}

Dynamic eqOp(Dynamic lhs, Dynamic rhs)
{
    return dynamic(lhs == rhs);
}

Dynamic neqOp(Dynamic lhs, Dynamic rhs)
{
    return dynamic(lhs != rhs);
}