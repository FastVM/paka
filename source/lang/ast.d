module lang.ast;

import std.algorithm;
import std.conv;
import std.meta;

alias NodeTypes = AliasSeq!(Call, String, Ident);

class Node
{
}

class Call : Node
{
    Node[] args;
    this(Node[] c)
    {
        args = c;
    }

    this(Node f, Node[] a)
    {
        args = f ~ a;
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
    }
}

class Char : Atom
{
    this(char c)
    {
        super([c]);
    }
}
