module paka.lib.enforce;

import purr.dynamic;
import purr.srcloc;
import std.algorithm;
import std.array;
import std.conv;

Enforce cvrt(Dynamic dyn)
{
    return cast(Enforce) dyn.tab.native;
}

Dynamic cvrt(Enf)(Enf enf)
{
    return new Table(emptyMapping, cast(void*) cast(Enforce) enf).dynamic;
}

string indent(alias rule = x => true)(string input)
{
    string ret;
    foreach (num, line; input.splitter!(x => x == '\n').array)
    {
        if (num != 0)
        {
            ret ~= '\n';
        }
        if (rule(num))
        {
            ret ~= "    ";
        }
        ret ~= line;
    }
    return ret;
}

class Enforce
{
    Location loc;

    bool ok()
    {
        Dynamic val = eval;
        return val.type != Dynamic.Type.nil && val.log != false;
    }

    Dynamic eval()
    {
        assert(false);
    }

    string fail()
    {
        assert(false);
    }

    typeof(this) annot(Dynamic[] args)
    {
        loc.line = args[0].as!size_t;
        loc.column = args[1].as!size_t;
        return this;
    }
}

class EnforceLiteral : Enforce
{
    Dynamic val;

    this(Dynamic v)
    {
        val = v;
    }

    override Dynamic eval()
    {
        return val;
    }

    override string fail()
    {
        return val.to!string;
    }
}

class EnforceBinary(string opname) : Enforce
{
    string op;
    Enforce lhs;
    Enforce rhs;
    Dynamic got;

    this(Enforce l, Enforce r)
    {
        op = opname;
        lhs = l;
        rhs = r;
    }

    override Dynamic eval()
    {
        Dynamic lhsv = lhs.eval;
        Dynamic rhsv = rhs.eval;
        got = mixin("lhsv" ~ opname ~ "rhsv").dynamic;
        return got;
    }

    override string fail()
    {
        string ret;
        ret ~= '\n';
        ret ~= lhs.fail;
        ret ~= '\n';
        ret ~= lhs.fail;
        ret = op ~ " => " ~ got.to!string ~ ret.indent;
        return ret;
    }
}

class EnforceLogical(string opname) : Enforce
{
    string op;
    Enforce lhs;
    Enforce rhs;
    Dynamic got;

    this(Enforce l, Enforce r)
    {
        op = opname;
        lhs = l;
        rhs = r;
    }

    override Dynamic eval()
    {
        Dynamic lhsd = lhs.eval;
        Dynamic rhsd = rhs.eval;
        bool lhsb = lhsd.type != Dynamic.Type.nil && lhsd.log;
        bool rhsb = rhsd.type != Dynamic.Type.nil && rhsd.log;
        got = mixin("lhsb" ~ opname ~ "rhsb").dynamic;
        return got;
    }

    override string fail()
    {
        string ret;
        ret ~= '\n';
        ret ~= lhs.fail;
        ret ~= '\n';
        ret ~= lhs.fail;
        ret = op ~ " => " ~ got.to!string ~ ret.indent;
        return ret;
    }
}

Dynamic pakaenforce(Args args)
{
    Enforce enf = args[0].cvrt;
    if (!enf.ok)
    {
        throw new Exception("assert failure: " ~ enf.fail);
    }
    return Dynamic.nil;
}

Dynamic enforcecall(Args args)
{
    assert(false);
}

Dynamic enforcespeicalcall(Args args)
{
    switch (args[2].str)
    {
    case "&&":
        return new EnforceLogical!"&&"(args[3].cvrt, args[4].cvrt).annot(args).cvrt;
    case "||":
        return new EnforceLogical!"||"(args[3].cvrt, args[4].cvrt).annot(args).cvrt;
    default:
        assert(false, args.to!string);
    }
}

Dynamic enforcelit(Args args)
{
    return new EnforceLiteral(args[2]).annot(args).cvrt;
}

Dynamic enforcevar(Args args)
{
    assert(false);
}

Dynamic enforcestr(Args args)
{
    assert(false);
}
