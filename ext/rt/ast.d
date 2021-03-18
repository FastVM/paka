module ext.rt.ast;

import purr.io;
import std.conv;
import purr.dynamic;
import purr.base;
import purr.srcloc;
import purr.ast;
import purr.parse;
import purr.bytecode;
import purr.ir.walk;
import ext.rt.astcons;

Pair[] lib2ast()
{
    Pair[] ret;
    ret ~= FunctionPair!astparse("parse");
    ret ~= FunctionPair!astcompile("compile");
    ret ~= FunctionPair!astcall("call");
    ret ~= FunctionPair!astident("ident");
    ret ~= FunctionPair!aststring("string");
    return ret;
}

private:
Dynamic astcall(Args args)
{
    Mapping ret;
    ret["id".dynamic] = "call".dynamic;
    Dynamic[] nodes;
    foreach (k, arg; args)
    {
        if (arg.type == Dynamic.Type.arr)
        {
            nodes ~= arg.arr;
        }
        else if (arg.type == Dynamic.Type.tab)
        {
            nodes ~= arg;
        }
        else
        {
            throw new Exception("purr.ast.call: args.(" ~ k.to!string ~ ": must be an ast node");
        }
    }
    ret["args".dynamic] = nodes.dynamic;
    return ret.dynamic;
}

Dynamic astident(Args args)
{
    Mapping ret;
    ret["id".dynamic] = "ident".dynamic;
    if (args[0].type == Dynamic.Type.str)
    {
        ret["repr".dynamic] = args[0];
    }
    else if (args[0].type == Dynamic.Type.sml)
    {
        ret["repr".dynamic] = args[0].as!double.to!string.dynamic;
    }
    else
    {
        throw new Exception("purr.ast.ident: args.(0) ident must be a string or number");
    }
    return ret.dynamic;
}

Dynamic aststring(Args args)
{
    Mapping ret;
    ret["id".dynamic] = "string".dynamic;
    if (args[0].type == Dynamic.Type.str)
    {
        ret["repr".dynamic] = args[0];
    }
    else
    {
        throw new Exception("purr.ast.string: args.(0) must be a string");
    }
    return ret.dynamic;
}

Dynamic astparse(Args args)
{
    Args orig = args;
    Location loc = Location(1, 1, "__parse__", args[0].str); 
    args = args[1..$];
    string lang = langNameDefault;
    if (args.length == 1)
    {
        lang = args[0].str;
        args = args[1..$];
    }
    if (args.length != 0)
    {
        throw new Exception("wrong arguments to function: " ~ orig.to!string[1..$-1]);
    }
    Node parsed = loc.parse(lang);
    // else
    // {
    //     throw new Exception("bad number of arguments: " ~ args.length.to!string);
    // }
    return parsed.astDynamic;
}

Dynamic astcompile(Args args)
{
    Node node = args[0].getNode;
    size_t ctx = void;
    if (args.length == 2)
    {
        ctx = args[1].as!size_t;
    }
    else if (args.length == 1)
    {
        ctx = rootBases.length - 1;
    }
    else
    {
        throw new Exception("wrong arguments to function: " ~ args.to!string[1..$-1]);
    }
    Walker walker = new Walker;
    Function func = walker.walkProgram(node, rootBases.length-1);
    return func.dynamic;
}
