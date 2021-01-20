module purr.ast;

import std.algorithm;
import std.conv;
import std.meta;
import purr.srcloc;

/// all possible node types
alias NodeTypes = AliasSeq!(Call, String, Ident);

/// any node, not valid in the ast
class Node
{
    Span span;
    string id="node";
}

/// call of function or operator call
class Call : Node
{
    Node[] args;
    this(Node[] c)
    {
        args = c;
        id="call";
    }

    this(Node f, Node[] a)
    {
        args = [f] ~ a;
        id="call";
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
}

/// atom like a string or a number
class Atom : Node
{
    string repr;
    this(string r)
    {
        repr = r;
        id="atom";
    }

    override string toString()
    {
        return repr;
    }
}

/// string type
class String : Atom
{
    this(string s)
    {
        super(s);
        id="string";
    }

    override string toString()
    {
        return "\"" ~ repr ~ "\"";
    }
}

/// ident or number, detects at runtime
class Ident : Atom
{
    this(string s)
    {
        super(s);
        id="ident";
    }
}
