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
import purr.ir.opt;
import purr.ir.repr;
import purr.type.check;

void modifyInstr(T)(Bytecode func, T index, ushort v)
{
    func.instrs[index - 2 .. index] = *cast(ubyte[2]*)&v;
}

void modifyInstrAhead(T)(Bytecode func, T index, Opcode replacement)
{
    func.instrs[index] = replacement;
}

void removeCount(T1, T2)(Bytecode func, T1 index, T2 argc)
{
    func.instrs = func.instrs[0 .. index] ~ func.instrs[index + 2 * argc + 1 .. $];
}

void pushInstr(Bytecode func, Opcode op, ushort[] shorts = null, int size = 0)
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
    Bytecode func;
    Opt opt;
    TypeChecker tc;

    this()
    {
        opt = new Opt;
        tc = new TypeChecker;
    }
    
    string[] predef(BasicBlock block, string[] checked = null, string[] nodef=null)
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
            if (LoadInstruction li = cast(LoadInstruction) instr)
            {
                if (!checked.canFind(li.var))
                {
                    nodef ~= li.var;
                }
            }
            if (StoreInstruction si = cast(StoreInstruction) instr)
            {
                if (!checked.canFind(si.var) && !nodef.canFind(si.var))
                {
                    checked ~= si.var;
                }
            }
        }
        foreach (blk; block.exit.target)
        {
            checked = predef(blk, checked, nodef);
        }
        return checked;
    }

    void emitInFunc(Bytecode newFunc, BasicBlock block)
    {
        tc.enterFunc;
        Bytecode oldFunc = func;
        scope (exit)
        {
            func = oldFunc;
        }
        func = newFunc;
        emit(block);
        tc.exitFunc;
    }

    ushort emit(BasicBlock block)
    {
        if (block.place < 0)
        {
            // opt.opt(block);
            string[] pres = predef(block);
            foreach (pre; pres)
            {
                func.stab.define(pre);
            }
            tc.enterBlock(pres);
            if (dumpir)
            {
                writeln(block);
            }
            block.place = cast(int) func.instrs.length;
            foreach (instr; block.instrs)
            {
                func.spans ~= instr.span;
                emit(instr);
            }
            emit(block.exit);
        }
        return cast(ushort) block.place;
    }

    void emit(Emittable em)
    {
        static foreach (Instr; InstrTypes)
        {
            if (typeid(em) == typeid(Instr))
            {
                emit(cast(Instr) em);
                tc.emit(cast(Instr) em);
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
        func.modifyInstr(j0, t0);
        func.modifyInstr(j1, t1);
    }

    void emit(GotoBranch branch)
    {
        if (branch.target.length != 0)
        {
            if (branch.target[0].instrs.length != 0)
            {
                pushInstr(func, Opcode.jump, [cast(ushort) ushort.max]);
                size_t j0 = func.instrs.length;
                ushort t0 = emit(branch.target[0]);
                func.modifyInstr(j0, t0);
            }
            else
            {
                emit(branch.target[0].exit);
            }
        }
    }

    void emit(ReturnBranch branch)
    {
        pushInstr(func, Opcode.retval);
    }

    void emit(ConstReturnBranch branch)
    {
        pushInstr(func, Opcode.retconst, [cast(ushort) func.constants.length]);
        func.constants ~= branch.value;
    }

    void emit(ConstBranch branch)
    {
        ushort cacheno = cast(ushort) func.cached.length;
        pushInstr(func, Opcode.cbranch, [branch.ndeps, cacheno, cast(ushort) ushort.max, cast(ushort) ushort.max]);
        func.cached.length++;
        Dynamic[] newCheck = new Dynamic[branch.ndeps];
        foreach (ref value; newCheck)
        {
            value = gensym;
        }
        func.cacheCheck ~= newCheck;
        size_t j0 = func.instrs.length - ushort.sizeof;
        size_t j1 = func.instrs.length;
        ushort t0 = emit(branch.target[0]);
        pushInstr(func, Opcode.gocache, [cacheno, cast(ushort) ushort.max]);
        size_t jc = func.instrs.length;
        ushort t1 = emit(branch.target[1]);
        func.modifyInstr(j0, t0);
        func.modifyInstr(j1, t1);
        func.modifyInstr(jc, t1);
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
            int us = func.doCapture(store.var);
            if (us == -1)
            {
                pushInstr(func, Opcode.store, [cast(ushort)func.stab.define(store.var)]);
            }
            else
            {
                pushInstr(func, Opcode.cstore, [cast(ushort) us]);
            }
            // throw new Exception("not mutable: " ~ store.var);
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
            Bytecode.Lookup.Flags flags;
            if (us !is null)
            {
                pushInstr(func, Opcode.load, [cast(ushort)*us]);
                flags = func.stab.flags(load.var);
                unfound = false;
                load.capture = LoadInstruction.Capture.not;
            }
            else
            {
                int v = func.doCapture(load.var);
                if (v == -1) {
                    throw new Exception("variable not found: " ~ load.var);
                }
                pushInstr(func, Opcode.loadcap, [cast(ushort) v]);
                flags = func.captab.flags(v);
                unfound = false;
                load.capture = LoadInstruction.Capture.cap;
            }
        }
    }

    void emit(CallInstruction call)
    {
        pushInstr(func, Opcode.call, [cast(ushort) call.argc], cast(int)-call.argc);
    }

    void emit(TailCallBranch call)
    {
        pushInstr(func, Opcode.tcall, [cast(ushort) call.argc], cast(int)-call.argc);
    }

    void emit(StaticCallInstruction call)
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

    void emit(ArgNumberInstruction argno)
    {
        pushInstr(func, Opcode.argno, [cast(ushort) argno.argno]);
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
            func.pushInstr(Opcode.opindex);
            break;
            static foreach (i; operators)
            {
        case i:
                func.pushInstr(mixin("Opcode.op" ~ i));
                break sw;
            }
        }
    }

    void emit(ConstOperatorInstruction op)
    {
        void emitDefault()
        {
            func.pushInstr(Opcode.push, [cast(ushort) func.constants.length]);
            func.constants ~= op.rhs;
            if (op.op == "index")
            {
                func.pushInstr(Opcode.opindex);
            }
            static foreach (i; operators)
            {
                if (op.op == i)
                {
                    func.pushInstr(mixin("Opcode.op" ~ i));
                }
            }
        }

        switch (op.op)
        {
        case "index":
            func.pushInstr(Opcode.opindexc, [cast(ushort) func.constants.length]);   
            func.constants ~= op.rhs;
            break;
        case "add":
            double n = op.rhs.as!double;
            if (n % 1 == 0 && n < ushort.max)
            {
                func.pushInstr(Opcode.opinc, [cast(ushort) n]);
            }
            else 
            {
                emitDefault();
            }
            break;
        case "sub":
            double n = op.rhs.as!double;
            if (n % 1 == 0 && n <= ushort.max)
            {
                func.pushInstr(Opcode.opdec, [cast(ushort) n]);
            }
            else 
            {
                emitDefault();
            }
            break;
        default:
            emitDefault();
        }
    }

    void emit(LambdaInstruction lambda)
    {
        func.flags |= Bytecode.flags.isLocal;
        Bytecode newFunc = new Bytecode;
        newFunc.parent = func;
        newFunc.args = lambda.argNames;
        func.pushInstr(Opcode.sub, [cast(ushort) func.funcs.length]);
        opt.opt(lambda.entry);
        emitInFunc(newFunc, lambda.entry);
        func.funcs ~= newFunc;
    }

    void emit(PopInstruction pop)
    {
        func.pushInstr(Opcode.pop);
    }
}
