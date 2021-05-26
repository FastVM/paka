module ext.passerine.parse.syntax;

import purr.io;
import std.algorithm;
import std.array;
import std.conv;
import purr.srcloc;
import purr.dynamic;
import purr.ir.walk;
import purr.ast.ast;
import purr.ast.cons;
import ext.passerine.tokens;
import ext.passerine.parse.parse;
import ext.passerine.parse.util;

Dynamic[2][][] syntaxMacros = [null];
Table[] nameSubs;

Table matchMacro(Dynamic[] pattern, Node[] flatlike)
{
    if (flatlike.length < pattern.length)
    {
        return Table.empty;
    }
    Table ret = Table.empty;
    foreach (index, value; pattern)
    {
        Node cur = flatlike[index];
        if (value.arr[0].str == "keyword")
        {
            if (Ident id = cast(Ident) cur)
            {
                if (id.repr == value.arr[1].str)
                {
                    continue;
                }
            }
            return Table.empty;
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
    if (Form call = cast(Form) node)
    {
        Node[] args;
        foreach (arg; call.args)
        {
            args ~= arg.macroLike(pattern);
        }
        return new Form("call", args);
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
    Token[] bodyTokens = tokens.tokens;
    tokens.readBlock;
    bodyTokens = bodyTokens[0 .. $ - tokens.tokens.length];
    syntaxMacros[$ - 1] ~= [pattern.dynamic, bodyTokens.map!tokDynamic.array.dynamic];
}

Dynamic locDynamic(SrcLoc loc)
{
    return [loc.line.dynamic, loc.column.dynamic, loc.file.dynamic].dynamic;
}

Dynamic spanDynamic(Span span)
{
    return [span.first.locDynamic, span.last.locDynamic].dynamic;
}

Dynamic tokDynamic(Token tok)
{
    Mapping ret = emptyMapping;
    ret["type".dynamic] = tok.type.to!string.dynamic;
    ret["value".dynamic] = tok.value.dynamic;
    ret["span".dynamic] = tok.span.spanDynamic;
    return new Table(ret).dynamic;
}

SrcLoc getLoc(Dynamic dyn)
{
    return SrcLoc(dyn.arr[0].as!size_t, dyn.arr[1].as!size_t, dyn.arr[2].str);
}

Span getSpan(Dynamic dyn)
{
    return Span(dyn.arr[0].getLoc, dyn.arr[1].getLoc);
}

Token getToken(Dynamic dyn)
{
    return Token(dyn.tab["span".dynamic].getSpan, dyn.tab["type".dynamic].str.to!(Token.Type), dyn.tab["value".dynamic].str);
}

TokenArray getTokens(Dynamic dyn)
{
    return newTokenArray(dyn.arr.map!getToken.array);
}