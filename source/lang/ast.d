module lang.ast;

import std.algorithm;
import std.conv;
import std.meta;
import lang.srcloc;

alias NodeTypes = AliasSeq!(Call, String, Ident);

class Node
{
    Span span;
    string id="node";
}

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

class Ident : Atom
{
    this(string s)
    {
        super(s);
        id="ident";
    }
}
