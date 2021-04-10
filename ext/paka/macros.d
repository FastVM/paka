module paka.macros;

import purr.io;
import std.array;
import std.algorithm;
import purr.dynamic;
import purr.ast.cons;
import purr.ast.ast;
import paka.parse.parse;
import paka.parse.util;
import paka.tokens;

Dynamic genCtx()
{
    Mapping map;
    return map.dynamic;
}

TokenArray gtoks;

Dynamic libid(Args args)
{
    string name = gtoks[0].value;
    gtoks.nextIs(Token.Type.ident);
    if (args.length == 0)
    {
        return new Ident(name).astDynamic;
    }
    else if (args.length == 1)
    {
        if (name != args[0].str)
        {
            throw new Exception("parse error: got wrong token in macro: " ~ name);
        }
        return new Ident(name).astDynamic;
    }
    else
    {
        throw new Exception("ctx.id: too many arguments (needs 0 or 1)");
    }
}

Dynamic libop(Args args)
{
    string name = gtoks[0].value;
    gtoks.nextIs(Token.Type.operator);
    if (args.length == 0)
    {
        return new Ident(name).astDynamic;
    }
    else if (args.length == 1)
    {
        if (name != args[0].str)
        {
            throw new Exception("parse error: got wrong token in macro: " ~ name);
        }
        return new Ident(name).astDynamic;
    }
    else
    {
        throw new Exception("ctx.op: too many arguments (needs 0 or 1)");
    }
}

Dynamic libexpr(Args args)
{
    if (args.length == 0)
    {
        return gtoks.readExprBase.astDynamic;
    }
    else if (args.length == 1)
    {
        return gtoks.readExpr(args[0].as!size_t).astDynamic;
    }
    else
    {
        throw new Exception("ctx.expr: too many arguments (needs 0 or 1)");
    }
}

Dynamic libbody(Args args)
{
    return gtoks.readBlockBody.astDynamic;
}

Dynamic libblock(Args args)
{
    return gtoks.readBlock.astDynamic;
}

Dynamic libwrap(Args args)
{
    switch(args[0].str)
    {
    case "()":
        return gtoks.readOpen!"()"[$-1].map!astDynamic.array.dynamic;
    case "[]":
        return gtoks.readOpen!"[]".map!astDynamic.array.dynamic;
    case "{}":
        return gtoks.readOpen!"{}".map!astDynamic.array.dynamic;
    default:
        throw new Exception("ctx.wrap: argumnet must be a surrounding pair {}, (), or {}");
    }
}

Dynamic libargs(Args args)
{
    return gtoks.readOpen!"()"[$-1].map!astDynamic.array.dynamic;
}

Dynamic libarray(Args args)
{
    return gtoks.readOpen!"()"[$-1].map!astDynamic.array.dynamic;
}

Dynamic libsym(Args args)
{
    return genSym.astDynamic;
}

Node readFromMacro(Dynamic func, ref TokenArray tokens)
{
    TokenArray last = gtoks;
    gtoks = tokens;
    scope (exit)
    {
        tokens = gtoks;
        gtoks = last;
    }
    Mapping tab;
    tab["id".dynamic] = dynamic(Fun(&libid));
    tab["op".dynamic] = dynamic(Fun(&libop));
    tab["expr".dynamic] = dynamic(Fun(&libexpr));
    tab["body".dynamic] = dynamic(Fun(&libbody));
    tab["block".dynamic] = dynamic(Fun(&libblock));
    tab["wrap".dynamic] = dynamic(Fun(&libwrap));
    tab["args".dynamic] = dynamic(Fun(&libargs));
    tab["sym".dynamic] = dynamic(Fun(&libsym));
    Dynamic ast = func([tab.dynamic]);
    return ast.getNode;
}
