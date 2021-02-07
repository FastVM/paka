module paka.subparser;

import std.conv;
import std.string;
import std.ascii;
import std.algorithm;
import purr.ast;
import purr.walk;

Node transform(alias f)(Node from)
{
    Node ret = f(from);
    assert(ret !is null);
    ret.span = from.span;
    return ret;
}

alias parseAssert = transform!parseAssertImpl;
Node parseAssertImpl(Node from)
{
    Node[] args;
    args ~= new Call(new Ident("_paka_enforce"), [parseAssertPart(from)]);
    return new Call(new Ident("@do"), args);
}

alias parseAssertPart = transform!parseAssertPartImpl;
Node parseAssertPartImpl(Node from)
{
    Node[] args;
    args ~= new Ident(from.span.first.line.to!string);
    args ~= new Ident(from.span.first.column.to!string);
    if (Call call = cast(Call) from)
    {
        if (Ident id = cast(Ident) call.args[0])
        {
            if (specialForms.canFind(id.repr))
            {
                args ~= new String(id.repr);
                foreach (arg; call.args[1..$])
                {
                    args ~= parseAssertPart(arg);
                }
                return new Call(new Ident("_paka_enforce_special_call"), args);
            }
        }
        foreach (arg; call.args)
        {
            args ~= parseAssertPart(arg);
        }
        return new Call(new Ident("_paka_enforce_call"), args);
    }
    if (Ident id = cast(Ident) from)
    {
        if (id.repr.isNumeric)
        {
            args ~= id;
            return new Call(new Ident("_paka_enforce_lit"), args);
        }
        else if (id.repr == "true" || id.repr == "false")
        {
            args ~= id;
            return new Call(new Ident("_paka_enforce_lit"), args);
        }
        else
        {
            args ~= id;
            args ~= new String(id.repr);
            return new Call(new Ident("_paka_enforce_var"), args);
        }
    }
    if (String str = cast(String) from)
    {
        args ~= str;
        return new Call(new Ident("_paka_enforce_lit"), args);
    }
    assert(false);
}
