module purr.ir.repr;

import core.memory;
import std.conv;
import std.array;
import std.algorithm;
import std.typecons;
import std.meta;
import purr.io;
import purr.srcloc;
import purr.vm.bytecode;
import purr.dynamic;
import purr.inter;
import purr.ir.opt;

alias InstrTypes = AliasSeq!(LogicalBranch, TailCallBranch, GotoBranch, ReturnBranch, ConstReturnBranch, 
        BuildTupleInstruction,BuildArrayInstruction, BuildTableInstruction, CallInstruction, StaticCallInstruction, PushInstruction,
        OperatorInstruction, ConstOperatorInstruction, LambdaInstruction, PopInstruction,
        StoreInstruction, StoreIndexInstruction, LoadInstruction, RecInstruction, ArgNumberInstruction);

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

final class BasicBlock
{
    Span span;
    string name;
    Instruction[] instrs;
    Branch exit;
    int place = -1;

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

    this(BasicBlock ift, BasicBlock iff)
    {
        target = [ift, iff];
    }

    override string toString()
    {
        string ret;
        ret ~= "branch " ~ target[0].name ~ " " ~ target[1].name ~ " \n";
        return ret;
    }
}


class GotoBranch : Branch
{
    this()
    {
        target = [];
    }

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

class ConstReturnBranch : Branch
{
    Dynamic value;
    this(Dynamic val)
    {
        value = val;
    }

    override string toString()
    {
        string ret;
        ret ~= "const-return value=";
        ret ~= value.to!string;
        ret ~= '\n';
        return ret;
    }
}

class BuildTupleInstruction : Instruction
{
    int argc;

    this(int a)
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
    int argc;

    this(int a)
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
    int argc;

    this(int a)
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

class CallInstruction : Instruction
{
    int argc;

    this(int a)
    {
        argc = a;
    }

    override string toString()
    {
        string ret;
        ret ~= "call " ~ argc.to!string ~ "\n";
        return ret;
    }
}

class TailCallBranch : Branch
{
    int argc;

    this(int ac)
    {
        argc = ac;
    }

    override string toString()
    {
        string ret;
        ret ~= "tail-call " ~ argc.to!string ~ "\n";
        return ret;
    }
}

class StaticCallInstruction : Instruction
{
    Dynamic func;
    int argc;

    this(Dynamic fn, int ac)
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
    int argc;

    this(int a)
    {
        argc = a;
    }

    override string toString()
    {
        string ret;
        ret ~= "rec argc=" ~ argc.to!string~ "\n";
        return ret;
    }
}

enum string[] operators = [
        "cat", "add", "mod", "neg", "sub", "mul", "div", "lt", "gt", "lte", "gte",
        "neq", "eq"
    ];

class OperatorInstruction : Instruction
{
    string[] attrs;
    string op;

    this(string oper, string[] ats=null)
    {
        op = oper;
        attrs = ats;
        assert(operators.canFind(oper) || oper == "index");
    }

    override string toString()
    {
        string ret;
        ret ~= "operator " ~ op ~ " " ~ attrs.map!(x => "@" ~ x).join(" ") ~ "\n";
        return ret;
    }
}

class ConstOperatorInstruction : Instruction
{
    string[] attrs;
    string op;
    Dynamic rhs;

    this(string oper, Dynamic r, string[] ats=null)
    {
        op = oper;
        attrs = ats;
        rhs = r;
        assert(operators.canFind(oper) || oper == "index");
    }

    override string toString()
    {
        string ret;
        ret ~= "const-operator " ~ op ~ " rhs=" ~ rhs.to!string ~ " " ~ attrs.map!(x => "@" ~ x).join(" ") ~ "\n";
        return ret;
    }
}

class LambdaInstruction : Instruction
{
    BasicBlock entry;
    string[] argNames;

    this(BasicBlock bb, string[] args)
    {
        entry = bb;
        argNames = args;
    }

    override string toString()
    {
        string ret;
        ret ~= "lambda " ~ entry.name ~ " (" ~ argNames.join(", ").to!string ~ ")" ~ "\n";
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
    string var;

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
class ArgNumberInstruction : Instruction
{
    int argno;

    this(int arg)
    {
        argno = arg;
    }
    
    override string toString()
    {
        string ret;
        ret ~= "arg num=";
        ret ~= argno.to!string;
        ret ~= "\n";
        return ret;
    }
}
