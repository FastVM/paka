module purr.ast.ast;

import std.algorithm;
import std.conv;
import std.meta;
import purr.dynamic;
import purr.srcloc;

/// all possible node types
alias NodeTypes = AliasSeq!(Call, Value, Ident);

enum NodeKind
{
    base,
    call,
    ident,
    value,
}

/// any node, not valid in the ast
class Node
{
    Span span;

    NodeKind id()
    {
        return NodeKind.base;
    }
}

/// call of function or operator call
class Call : Node
{
    Node[] args;

    this(Node[] a=null)
    {
        args = a;
    }

    this(Value f, Node[] a=null)
    {
        args = f ~ a;
    }

    this(string f, Node[] a=null)
    {
        args = new Ident(f) ~ a;
    }

    override string toString()
    {
        char[] ret;
        ret ~= "(";
        foreach (i, v; args)
        {
            if (i != 0)
            {
                ret ~= " ";
            }
            ret ~= v.to!string;
        }
        ret ~= ")";
        return cast(string) ret;
    }

    override NodeKind id()
    {
        return NodeKind.call;
    }
}

size_t usedSyms;

Ident genSym()
{
    usedSyms++;
    return new Ident("_purr_" ~ to!string(usedSyms - 1));
}

template ident(string name){
    Ident value;

    shared static this()
    {
        value = new Ident(name);
    }

    Ident ident() {
        return value;
    }
}

/// ident or number, detects at runtime
class Ident : Node
{
    string repr;

    this(string s)
    {
        repr = s;
    }

    override NodeKind id()
    {
        return NodeKind.ident;
    }

    override string toString()
    {
        return repr;
    }
}

/// dynamic value literal
class Value : Node
{
    Dynamic value;

    this(T)(T v)
    {
        value = v.dynamic;
    }

    override string toString()
    {
        return "[" ~ value.to!string ~ "]";
    }

    override NodeKind id()
    {
        return NodeKind.value;
    }
}
