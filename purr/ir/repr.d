module purr.ir.repr;

import std.stdio;
import std.conv;
import std.array;
import std.algorithm;
import std.typecons;
import std.meta;
import purr.srcloc;
import purr.bytecode;
import purr.dynamic;
import purr.inter;
import purr.ir.emit;
import purr.ir.opt;

alias InstrTypes = AliasSeq!(BooleanBranch, GotoBranch, ReturnBranch,
        BuildArrayInstruction, BuildTableInstruction,
        CallInstruction, PushInstruction, OperatorInstruction, LambdaInstruction,
        PopInstruction,
        IndexStoreInstruction,
        StoreInstruction, OperatorStoreInstruction, StorePopInstruction,
        OperatorStorePopInstruction, LoadInstruction, ArgsInstruction,);

size_t nameCount;

void modifyInstr(T)(Function func, T index, ushort v)
{
    func.instrs[index - 2 .. index] = *cast(ubyte[2]*)&v;
}

void modifyInstrAhead(T)(Function func, T index, Opcode replacement)
{
    func.instrs[index] = replacement;
}

void removeCount(T1, T2)(Function func, T1 index, T2 argc)
{
    func.instrs = func.instrs[0 .. index] ~ func.instrs[index + 2 * argc + 1 .. $];
}

void pushInstr(Function func, Opcode op, ushort[] shorts = null, int size = 0)
{
    func.stackAt[func.instrs.length] = func.stackSizeCurrent;
    func.instrs ~= cast(ubyte) op;
    foreach (i; shorts)
    {
        func.instrs ~= *cast(ubyte[2]*)&i;
    }
    if (func.spans.length != 0)
    {
        while (func.spans.length < func.instrs.length)
        {
            func.spans ~= func.spans[$ - 1];
        }
    }
    int* psize = op in opSizes;
    if (psize !is null)
    {
        func.stackSizeCurrent += *psize;
    }
    else
    {
        func.stackSizeCurrent += size;
    }
    if (func.stackSizeCurrent > func.stackSize)
    {
        func.stackSize = func.stackSizeCurrent;
    }
    assert(func.stackSizeCurrent >= 0);
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

string genName(string prefix)()
{
    nameCount++;
    return prefix ~ nameCount.to!string;
}

BasicBlock[] bbchecked;

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

    string[] predef(string[] checked = null)
    {
        assert(exit !is null, this.to!string);
        foreach (i; bbchecked)
        {
            if (i is this)
            {
                return checked;
            }
        }
        bbchecked ~= this;
        scope (exit)
        {
            bbchecked.length--;
        }
        foreach (instr; instrs)
        {
            if (AssignmentInstruction si = cast(AssignmentInstruction) instr)
            {
                if (!checked.canFind(si.var))
                {
                    checked ~= si.var;
                }
            }
        }
        foreach (blk; exit.target)
        {
            checked = blk.predef(checked);
        }
        return checked;
    }

    bool within(Function func)
    {
        return !(func !in counts);
    }

    ushort entry(Function func)
    {
        emit(func);
        return counts[func];
    }

    void emit(Function func)
    {
        if (!within(func))
        {
            this.optimize;
            if (dumpbytecode)
            {
                writeln(this);
            }
            counts[func] = cast(ushort) func.instrs.length;
            foreach (sym; predef)
            {
                if (sym !in func.stab.byName)
                {
                    func.stab.define(sym);
                }
            }
            foreach (instr; instrs)
            {
                instr.enter(func);
                instr.emit(func);
                instr.exit(func);
            }
            exit.emit(func);
        }
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

class Emitter
{
    Span span;

    final void enter(Function func)
    {
        func.spans ~= span;
    }

    void emit(Function func)
    {
        assert(false);
    }

    final void exit(Function func)
    {
    }
}

class Instruction : Emitter
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

class Branch : Emitter
{
    BasicBlock[] target;
}

class BooleanBranch : Branch
{
    this(BasicBlock ift, BasicBlock iff)
    {
        target = [ift, iff];
    }

    override void emit(Function func)
    {
        if (!target[0].within(func))
        {
            func.pushInstr(Opcode.iffalse, [cast(ushort) ushort.max]);
            size_t iff = func.instrs.length;
            target[0].emit(func);
            ushort t1 = target[1].entry(func);
            func.modifyInstr(iff, t1);
        }
        else if (!target[1].within(func))
        {
            func.pushInstr(Opcode.iftrue, [cast(ushort) ushort.max]);
            size_t ift = func.instrs.length;
            target[1].emit(func);
            ushort t0 = target[0].entry(func);
            func.modifyInstr(ift, t0);
        }
        else
        {
            func.pushInstr(Opcode.iftrue, [cast(ushort) ushort.max]);
            size_t j0 = func.instrs.length;
            func.pushInstr(Opcode.jump, [cast(ushort) ushort.max]);
            size_t j1 = func.instrs.length;
            ushort t0 = target[0].entry(func);
            ushort t1 = target[1].entry(func);
            func.modifyInstr(j0, t0);
            func.modifyInstr(j1, t1);
        }
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

    override void emit(Function func)
    {
        func.pushInstr(Opcode.jump, [target[0].entry(func)]);
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
    override void emit(Function func)
    {
        func.pushInstr(Opcode.retval);
    }

    override string toString()
    {
        string ret;
        ret ~= "return\n";
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

    override void emit(Function func)
    {
        func.pushInstr(Opcode.array, [cast(ubyte) argc], cast(int)(1 - argc));
    }

    override string toString()
    {
        string ret;
        ret ~= "return\n";
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

    override void emit(Function func)
    {
        func.pushInstr(Opcode.table, [cast(ubyte) argc], cast(int)(1 - argc));
    }

    override string toString()
    {
        string ret;
        ret ~= "return\n";
        return ret;
    }
}

class CallInstruction : Instruction
{
    size_t argc;

    this(size_t ac)
    {
        argc = ac;
    }

    override void emit(Function func)
    {
        func.pushInstr(Opcode.call, [cast(ushort) argc], cast(int)-argc);
    }

    override string toString()
    {
        string ret;
        ret ~= "call " ~ argc.to!string ~ "\n";
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

    override void emit(Function func)
    {
        func.pushInstr(Opcode.push, [cast(ushort) func.constants.length]);
        func.constants ~= value;
    }

    override string toString()
    {
        string ret;
        ret ~= "push " ~ value.to!string ~ "\n";
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

    override void emit(Function func)
    {
    sw:
        final switch (op)
        {
        case "index":
            func.pushInstr(Opcode.index);
            break;
            static foreach (i; operators)
            {
        case i:
                func.pushInstr(mixin("Opcode.op" ~ i));
                break sw;
            }
        }
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
    string[] argNames;

    this(BasicBlock bb, string[] args)
    {
        entry = bb;
        argNames = args;
    }

    override void emit(Function func)
    {
        func.flags |= Function.flags.isLocal;
        Function newFunc = new Function;
        newFunc.parent = func;
        newFunc.args = argNames;
        entry.emit(newFunc);
        func.pushInstr(Opcode.sub, [cast(ushort) func.funcs.length]);
        func.funcs ~= newFunc;
    }

    override string toString()
    {
        string ret;
        ret ~= "lambda " ~ entry.name ~ "\n";
        return ret;
    }
}

class PopInstruction : Instruction
{
    override void emit(Function func)
    {
        func.pushInstr(Opcode.pop);
    }

    override string toString()
    {
        string ret;
        ret ~= "pop\n";
        return ret;
    }
}

class IndexStoreInstruction : Instruction
{
    override void emit(Function func)
    {
        func.pushInstr(Opcode.istore);
        func.pushInstr(Opcode.push, [cast(ushort) func.constants.length]);
        func.constants ~= Dynamic.nil;
    }

    override string toString()
    {
        string ret;
        ret ~= "index-store\n";
        return ret;
    }
}

class AssignmentInstruction : Instruction
{
    string var;
}

class StoreInstruction : AssignmentInstruction
{
    this(string v)
    {
        var = v;
    }

    override void emit(Function func)
    {
        uint ius = func.stab[var];
        func.pushInstr(Opcode.store, [cast(ushort) ius]);
        func.pushInstr(Opcode.load, [cast(ushort) ius]);
    }

    override string toString()
    {
        string ret;
        ret ~= "store " ~ var ~ "\n";
        return ret;
    }
}

class OperatorStoreInstruction : AssignmentInstruction
{
    string op;
    this(string o, string v)
    {
        op = o;
        var = v;
    }

    override void emit(Function func)
    {
        uint ius = func.stab[var];
        func.pushInstr(Opcode.opstore, [
                cast(ushort) ius, cast(ushort) op.to!AssignOp
                ]);
        func.pushInstr(Opcode.load, [cast(ushort) ius]);
    }

    override string toString()
    {
        string ret;
        ret ~= "operator-store " ~ op ~ " " ~ var ~ "\n";
        return ret;
    }
}

class StorePopInstruction : AssignmentInstruction
{
    this(string v)
    {
        var = v;
    }

    override void emit(Function func)
    {
        uint ius = func.stab[var];
        func.pushInstr(Opcode.store, [cast(ushort) ius]);
    }

    override string toString()
    {
        string ret;
        ret ~= "store-pop " ~ var ~ "\n";
        return ret;
    }
}

class OperatorStorePopInstruction : AssignmentInstruction
{
    string op;
    this(string o, string v)
    {
        op = o;
        var = v;
    }

    override void emit(Function func)
    {
        uint ius = func.stab[var];
        func.pushInstr(Opcode.opstore, [
                cast(ushort) ius, cast(ushort) op.to!AssignOp
                ]);
    }

    override string toString()
    {
        string ret;
        ret ~= "operator-store-pop " ~ op ~ " " ~ var ~ "\n";
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

    override void emit(Function func)
    {
        bool unfound = true;
        foreach (argno, argname; func.args)
        {
            if (argname == var)
            {
                func.pushInstr(Opcode.argno, [cast(ushort) argno]);
                unfound = false;
            }
        }
        if (unfound)
        {
            uint* us = var in func.stab.byName;
            Function.Lookup.Flags flags = void;
            if (us !is null)
            {
                func.pushInstr(Opcode.load, [cast(ushort)*us]);
                flags = func.stab.flags(var);
            }
            else
            {
                uint v = func.doCapture(var);
                func.pushInstr(Opcode.loadc, [cast(ushort) v]);
                flags = func.captab.flags(var);
            }
        }
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
    override void emit(Function func)
    {
        func.pushInstr(Opcode.args, null);
    }

    override string toString()
    {
        string ret;
        ret ~= "args\n";
        return ret;
    }
}
