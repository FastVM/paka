module passerine.parse.syntax;

import purr.io;
import std.algorithm;
import purr.dynamic;
import purr.ir.walk;
import purr.ast.ast;
import purr.ast.cons;
import passerine.tokens;
import passerine.parse.parse;
import passerine.parse.util;

Dynamic[2][][] syntaxMacros = [null];

Node readFromMacro(Dynamic tree, ref TokenArray tokens)
{
    assert(false);
}

Table matchMacro(Dynamic[] pattern, Node ast)
{
    Node[] flat;
    Call call = cast(Call) ast;
    if (call is null)
    {
        flat ~= ast;
    }
    else
    {
        while (true)
        {
            flat ~= call.args[$ - 1];
            if (Ident id = cast(Ident) call.args[0])
            {
                if (id.repr == "@call")
                {
                    if (Call nextCall = cast(Call) call.args[1])
                    {
                        call = nextCall;
                        continue;
                    }
                    else
                    {
                        flat ~= call.args[1];
                    }
                }
            }
            break;
        }
    }
    if (flat.length < pattern.length)
    {
        return null;
    }
    Table ret = new Table;
    foreach (index, value; pattern)
    {
        Node cur = flat[$-1-index];
        if (value.arr[0].str == "keyword")
        {
            if (Ident id = cast(Ident) cur)
            {
                if (id.repr != value.arr[1].str)
                {
                    return null;
                }
            }
        }
        else if (value.arr[0].str == "arg")
        {
            ret.set(value.arr[1], cur.astDynamic);
        }
        else
        {
            assert(false);
        }
    }
    return ret;
    // assert(false);
}

Node macroLike(Node node, Table pattern)
{
    if (Call call = cast(Call) node)
    {
        Node[] args;
        foreach (arg; call.args)
        {
            args ~= arg.macroLike(pattern);
        }
        return new Call(args);
    }
    else if (Value val = cast(Value) node)
    {
        return val;
    }
    else if (Ident id = cast(Ident) node)
    {
        if (Dynamic* dyn = id.repr.dynamic in pattern)
        {
            return getNode(*dyn);
        }
        else if (specialForms.canFind(id.repr))
        {
            return id;
        }
        else
        {
            Ident sym = genSym;
            pattern.set(id.repr.dynamic, sym.astDynamic);
            return sym;
        }
    }
    else
    {
        assert(false);
    }
}

void readSyntax(ref TokenArray tokens)
{
    tokens.nextIs(Token.Type.keyword, "syntax");
    Dynamic[] pattern;
    while (!tokens.first.isOpen("{"))
    {
        if (tokens.first.isOperator("'"))
        {
            tokens.nextIsAny;
            pattern ~= ["keyword".dynamic, tokens.first.value.dynamic].dynamic;
            tokens.nextIsAny;
        }
        else
        {
            pattern ~= ["arg".dynamic, tokens.first.value.dynamic].dynamic;
            tokens.nextIsAny;
        }
    }
    Dynamic value = tokens.readBlock.astDynamic;
    syntaxMacros[$ - 1] ~= [pattern.dynamic, value];
}
