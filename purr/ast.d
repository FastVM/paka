module purr.ast;

import std.algorithm;
import std.conv;
import std.meta;
import purr.dynamic;
import purr.srcloc;

/// all possible node types
alias NodeTypes = AliasSeq!(Call, Value, Ident);

/// some names to unittest
enum string[] names = [
        "1", "hello", "@do", "+", "'x", "Hello, World", "blood moon", "6", ""
    ];

/// any node, not valid in the ast
class Node
{
    Span span;
    string id = "node";

    unittest
    {
        assert(new Node().id == "node", "node should have id of node");
    }
}

/// call of function or operator call
class Call : Node
{
    Node[] args;
    this(Node[] c)
    {
        args = c;
        id = "call";
    }

    this(Node f, Node[] a)
    {
        args = [f] ~ a;
        id = "call";
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

    unittest
    {
        assert(new Call(null).id == "call", "call has the wrong id");
    }

    unittest
    {
        assert(new Call(null).to!string == "()", "a call with no arguments should be ()");
    }

    unittest
    {
        Call p20a = new Call(new Ident("print"), [new Ident("20")]);
        Call p20b = new Call([new Ident("print"), new Ident("20")]);
        string arepr = p20a.to!string;
        string brepr = p20b.to!string;
        assert(arepr == brepr, arepr ~ " should be the same as " ~ brepr);
        assert(arepr == "(print 20)");
    }
}

/// atom like a string or a number
class Atom : Node
{
    string repr;
    this(string r)
    {
        repr = r;
        id = "atom";
    }

    override string toString()
    {
        return repr;
    }

    unittest
    {
        assert(new Atom("atom").id == "atom", "atom has the wrong id");
    }
}

size_t usedSyms;

Ident genSym()
{
    usedSyms++;
    return new Ident("_purr_" ~ to!string(usedSyms -  1));
}

/// ident or number, detects at runtime
class Ident : Atom
{
    this(string s)
    {
        super(s);
        id = "ident";
    }

    unittest
    {
        assert(new Ident("varname").id == "ident", "ident has the wrong id");
    }

    unittest
    {
        foreach (name; names)
        {
            assert(new Ident(name).to!string == name,
                    "ident to!string should return the passed value");
        }
    }
}

/// dynamic value literal
class Value : Node 
{
    Dynamic value;

    this(T)(T v)
    {
        value = v.dynamic;
        id = "value";
    }

    override string toString()
    {
        return "[" ~ value.to!string ~ "]";
    }
}