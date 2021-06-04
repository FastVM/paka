module purr.ast.ast;

import std.algorithm;
import std.conv;
import std.meta;
import purr.dynamic;
import purr.srcloc;

/// all possible node types
alias NodeTypes = AliasSeq!(Form, Value, Ident);

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
final class Form : Node
{
    string form;
    Node[] args;

    this(Args...)(string f, Args as)
    {
        static foreach (a; as)
        {
            args ~= a;
        }
        form = f;
    }

    override string toString()
    {
        char[] ret;
        ret ~= "(";
        ret ~= form;
        foreach (i, v; args)
        {
            ret ~= " ";
            ret ~= v.to!string;
        }
        ret ~= ")";
        return cast(string) ret;
    }

    override NodeKind id()
    {
        return NodeKind.call;
    }

    override bool opEquals(Object arg)
    {
        Form other = cast(Form) arg;
        if (other is null)
        {
            return false;
        }
        return form == other.form && args == other.args;
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
final class Ident : Node
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

    override bool opEquals(Object arg)
    {
        Ident other = cast(Ident) arg;
        if (other is null)
        {
            return false;
        }
        return repr == other.repr;
    }
}

/// dynamic value literal
final class Value : Node
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

    override bool opEquals(Object arg)
    {
        Value other = cast(Value) arg;
        if (other is null)
        {
            return false;
        }
        return value == other.value;
    }
}
