module purr.ir.repr;

import core.memory;
import std.conv;
import std.array;
import std.algorithm;
import std.typecons;
import std.meta;
import purr.io;
import purr.srcloc;
import purr.bytecode;
import purr.dynamic;
import purr.inter;
import purr.ir.emit;
import purr.ir.opt;

alias InstrTypes = AliasSeq!(LogicalBranch, GotoBranch, ReturnBranch,
        BuildTupleInstruction,BuildArrayInstruction, BuildTableInstruction, FormInstruction, StaticFormInstruction, PushInstruction,
        OperatorInstruction, LambdaInstruction, PopInstruction,
        StoreInstruction, StoreIndexInstruction, LoadInstruction, ArgsInstruction, RecInstruction);

__gshared size_t nameCount;

string genName(string prefix)()
{
    size_t ret = void;
    synchronized
    {
        ret = nameCount++;
    }
    return prefix ~ ret.to!string;
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

class BasicBlock
{
    Span span;
    string name;
    Instruction[] instrs;
    Branch exit;
    ushort[Function] counts;

    this(string n = genName!"bb_")
    {
        name = n;
    }

    override string toString()
    {
        string ret;
        ret ~= name ~ ":\n";
        foreach (instr; instrs)
        {
            ret ~= instr.to!string;
        }
        if (exit !is null)
        {
            ret ~= exit.to!string;
        }
        return ret.indent!(x => x != 0);
    }
}

class Emittable
{
    Span span;
}

class Instruction : Emittable
{
    bool canGet(T)()
    {
        return cast(T) this !is null;
    }

    T get(T)()
    {
        assert(canGet!T, typeid(this).to!string ~ " is not a " ~ typeid(T).to!string);
        return cast(T) this;
    }
}

class Branch : Emittable
{
    BasicBlock[] target;
}

class LogicalBranch : Branch
{
    BasicBlock post;
    bool hasValue;

    this(BasicBlock ift, BasicBlock iff, BasicBlock post_, bool hasValue_)
    {
        target = [ift, iff];
        post = post_;
        hasValue = hasValue_;
    }

    override string toString()
    {
        string ret;
        ret ~= "if " ~ target[0].name ~ " " ~ target[1].name ~ " \n";
        return ret;
    }
}

class GotoBranch : Branch
{
    this(BasicBlock t)
    {
        target = [t];
    }

    override string toString()
    {
        string ret;
        ret ~= "goto " ~ target[0].name ~ " \n";
        return ret;
    }
}

class ReturnBranch : Branch
{
    override string toString()
    {
        string ret;
        ret ~= "return\n";
        return ret;
    }
}

class BuildTupleInstruction : Instruction
{
    size_t argc;

    this(size_t a)
    {
        argc = a;
    }

    override string toString()
    {
        string ret;
        ret ~= "array " ~ argc.to!string ~ "\n";
        return ret;
    }
}

class BuildArrayInstruction : Instruction
{
    size_t argc;

    this(size_t a)
    {
        argc = a;
    }

    override string toString()
    {
        string ret;
        ret ~= "array " ~ argc.to!string ~ "\n";
        return ret;
    }
}

class BuildTableInstruction : Instruction
{
    size_t argc;

    this(size_t a)
    {
        argc = a;
    }

    override string toString()
    {
        string ret;
        ret ~= "table " ~ argc.to!string ~ "\n";
        return ret;
    }
}

class FormInstruction : Instruction
{
    size_t argc;

    this(size_t ac)
    {
        argc = ac;
    }

    override string toString()
    {
        string ret;
        ret ~= "call " ~ argc.to!string ~ "\n";
        return ret;
    }
}


class StaticFormInstruction : Instruction
{
    Dynamic func;
    size_t argc;

    this(Dynamic fn, size_t ac)
    {
        func = fn;
        argc = ac;
    }

    override string toString()
    {
        string ret;
        ret ~= "static-call func=(?) " ~ argc.to!string ~ "\n";
        return ret;
    }
}

class PushInstruction : Instruction
{
    Dynamic value;

    this(Dynamic v)
    {
        value = v;
    }

    override string toString()
    {
        string ret;
        ret ~= "push " ~ value.to!string ~ "\n";
        return ret;
    }
}

class RecInstruction : Instruction
{
    this()
    {
    }

    override string toString()
    {
        string ret;
        ret ~= "rec\n";
        return ret;
    }
}

class InspectInstruction : Instruction
{
    this()
    {
    }

    override string toString()
    {
        string ret;
        ret ~= "inspect\n";
        return ret;
    }
}

enum string[] operators = [
        "cat", "add", "mod", "neg", "sub", "mul", "div", "lt", "gt", "lte", "gte",
        "neq", "eq"
    ];

class OperatorInstruction : Instruction
{
    string op;

    this(string oper)
    {
        op = oper;
        assert(operators.canFind(oper) || oper == "index");
    }

    override string toString()
    {
        string ret;
        ret ~= "operator " ~ op ~ "\n";
        return ret;
    }
}

class LambdaInstruction : Instruction
{
    BasicBlock entry;
    Dynamic[] argNames;

    this(BasicBlock bb, Dynamic[] args)
    {
        entry = bb;
        argNames = args;
    }

    override string toString()
    {
        string ret;
        ret ~= "lambda " ~ entry.name ~ " (" ~ cast(string) argNames.map!(x => x.str)
            .joiner(", ").array ~ ")" ~ "\n";
        return ret;
    }
}

class PopInstruction : Instruction
{

    override string toString()
    {
        string ret;
        ret ~= "pop\n";
        return ret;
    }
}

class StoreInstruction : Instruction
{
    string var;
    this(string v)
    {
        var = v;
    }

    override string toString()
    {
        string ret;
        ret ~= "store " ~ var ~ "\n";
        return ret;
    }
}

class StoreIndexInstruction : Instruction
{
    this()
    {
    }

    override string toString()
    {
        string ret;
        ret ~= "store-index\n";
        return ret;
    }
}

class LoadInstruction : Instruction
{
    enum Capture : ubyte
    {
        unk,
        not,
        arg,
        cap,
    }

    string var;
    Capture capture;

    this(string v)
    {
        var = v;
    }

    override string toString()
    {
        string ret;
        ret ~= "load " ~ var ~ "\n";
        return ret;
    }
}

class ArgsInstruction : Instruction
{
    override string toString()
    {
        string ret;
        ret ~= "args\n";
        return ret;
    }
}
