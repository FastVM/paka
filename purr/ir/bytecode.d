module purr.ir.bytecode;

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
import purr.ir.repr;

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
    func.instrs ~= *cast(ubyte[2]*)&op;
    foreach (i; shorts)
    {
        func.instrs ~= *cast(ubyte[2]*)&i;
    }
    if (func.spans.length == 0)
    {
        func.spans.length++;
    }
    while (func.spans.length < func.instrs.length)
    {
        func.spans ~= func.spans[$ - 1];
    }
    int* psize = op in opSizes;
    if (psize !is null)
    {
        func.stackSizeCurrent = func.stackSizeCurrent + *psize;
    }
    else
    {
        func.stackSizeCurrent = func.stackSizeCurrent + size;
    }
    if (func.stackSizeCurrent >= func.stackSize)
    {
        func.stackSize = func.stackSizeCurrent + 1;
    }
    assert(func.stackSizeCurrent >= 0);
}

final class BytecodeEmitter
{
    BasicBlock[] bbchecked;
    Function func;

    this()
    {
    }
    
    string[] predef(BasicBlock block, string[] checked = null)
    {
        assert(block.exit !is null, this.to!string);
        foreach (i; bbchecked)
        {
            if (i is block)
            {
                return checked;
            }
        }
        bbchecked ~= block;
        scope (exit)
        {
            bbchecked.length--;
        }
        foreach (instr; block.instrs)
        {
            if (StoreInstruction si = cast(StoreInstruction) instr)
            {
                if (!checked.canFind(si.var))
                {
                    checked ~= si.var;
                }
            }
        }
        foreach (blk; block.exit.target)
        {
            checked = predef(blk, checked);
        }
        return checked;
    }

    void emitInFunc(Function newFunc, BasicBlock block)
    {
        Function oldFunc = func;
        scope (exit)
        {
            func = oldFunc;
        }
        func = newFunc;
        emit(block);
    }

    ushort emit(BasicBlock block)
    {
        if (dumpir)
        {
            writeln(block);
        }
        ushort ret = cast(ushort) func.instrs.length;
        foreach (sym; predef(block))
        {
            if (sym !in func.stab.byName)
            {
                func.stab.define(sym);
            }
        }
        foreach (instr; block.instrs)
        {
            func.spans ~= instr.span;
            emit(instr);
        }
        emit(block.exit);
        return ret;
    }

    void emit(Emittable em)
    {
        static foreach (Instr; InstrTypes)
        {
            if (typeid(em) == typeid(Instr))
            {
                emit(cast(Instr) em);
                return;
            }
        }
        assert(false, "not emittable " ~ em.to!string);
    }

    void emit(LogicalBranch branch)
    {
        pushInstr(func, Opcode.branch, [cast(ushort) ushort.max, cast(ushort) ushort.max]);
        size_t j0 = func.instrs.length - ushort.sizeof;
        size_t j1 = func.instrs.length;
        ushort t0 = emit(branch.target[0]);
        ushort t1 = emit(branch.target[1]);
        func.modifyInstr(j1, t1);
        func.modifyInstr(j0, t0);
    }

    void emit(GotoBranch branch)
    {
        pushInstr(func, Opcode.jump, [cast(ushort) ushort.max]);
        size_t j0 = func.instrs.length;
        ushort t0 = emit(branch.target[0]);
        func.modifyInstr(j0, t0);
    }

    void emit(ReturnBranch branch)
    {
        pushInstr(func, Opcode.retval);
    }

    void emit(BuildArrayInstruction arr)
    {
        pushInstr(func, Opcode.array, [cast(ubyte) arr.argc], cast(int)(1 - arr.argc));
    }

    void emit(BuildTupleInstruction arr)
    {
        pushInstr(func, Opcode.tuple, [cast(ubyte) arr.argc], cast(int)(1 - arr.argc));
    }

    void emit(BuildTableInstruction table)
    {
        pushInstr(func, Opcode.table, [cast(ubyte) table.argc], cast(int)(1 - table.argc));
    }

    void emit(StoreInstruction store)
    {
        if (uint* ius = store.var in func.stab.byName)
        {
            pushInstr(func, Opcode.store, [cast(ushort)*ius]);
        }
        else
        {
            throw new Exception("not mutable: " ~ store.var);
        }
    }

    void emit(StoreIndexInstruction store)
    {
        pushInstr(func, Opcode.istore, []);
    }

    void emit(LoadInstruction load)
    {
        bool unfound = true;
        foreach (argno, argname; func.args)
        {
            if (argname == load.var)
            {
                pushInstr(func, Opcode.argno, [cast(ushort) argno]);
                unfound = false;
                load.capture = LoadInstruction.Capture.arg;
            }
        }
        if (unfound)
        {
            uint* us = load.var in func.stab.byName;
            Function.Lookup.Flags flags;
            if (us !is null)
            {
                pushInstr(func, Opcode.load, [cast(ushort)*us]);
                flags = func.stab.flags(load.var);
                unfound = false;
                load.capture = LoadInstruction.Capture.not;
            }
            else
            {
                uint v = func.doCapture(load.var);
                pushInstr(func, Opcode.loadc, [cast(ushort) v]);
                flags = func.captab.flags(load.var);
                unfound = false;
                load.capture = LoadInstruction.Capture.cap;
            }
        }
    }

    void emit(FormInstruction call)
    {
        pushInstr(func, Opcode.call, [cast(ushort) call.argc], cast(int)-call.argc);
    }

    void emit(StaticFormInstruction call)
    {
        pushInstr(func, Opcode.scall, [cast(ushort) func.constants.length, cast(ushort) call.argc], cast(int)(1-call.argc));
        func.constants ~= call.func;
    }

    void emit(PushInstruction push)
    {
        pushInstr(func, Opcode.push, [cast(ushort) func.constants.length]);
        func.constants ~= push.value;
    }

    void emit(RecInstruction rec)
    {
        pushInstr(func, Opcode.rec, []);
    }

    void emit(InspectInstruction inspect)
    {
        func.pushInstr(Opcode.inspect, null);
    }

    void emit(OperatorInstruction op)
    {
    sw:
        final switch (op.op)
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

    void emit(LambdaInstruction lambda)
    {
        func.flags |= Function.flags.isLocal;
        Function newFunc = new Function;
        newFunc.parent = func;
        newFunc.args = lambda.argNames;
        func.pushInstr(Opcode.sub, [cast(ushort) func.funcs.length]);
        emitInFunc(newFunc, lambda.entry);
        func.funcs ~= newFunc;
    }

    void emit(PopInstruction pop)
    {
        func.pushInstr(Opcode.pop);
    }

    void emit(ArgsInstruction args)
    {
        func.pushInstr(Opcode.args, null);
    }
}
