module wacons;

import std.algorithm;
import std.array;
import std.conv;

class Ast
{
    override string toString()
    {
        assert(false);
    }
}

final nclass Form(string s) : Ast
{
    string name = s;
    Ast[] children;

    this(Args...)(Args args)
    {
        static foreach (arg; args)
        {
            children ~= arg;
        }
    }

    override string toString()
    {
        return `(` ~ name ~ ` ` ~ children.map!(to!string).join(" ") ~ `)`;
    }
}

final class Literal : Ast
{
    string res;

    this(Arg)(Arg arg)
    {
        static if (is(Arg == string))
        {
            res ~= arg;
        }
        else
        {
            res ~= arg.to!string;
        }
    }

    override string toString()
    {
        return res;
    }
}
