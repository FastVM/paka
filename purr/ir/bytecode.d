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
import purr.ir.types;

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
    while (func.spans.length < func.instrs.length)
    {
        func.spans ~= func.spans[$ - 1];
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
    if (func.stackSizeCurrent >= func.stackSize)
    {
        func.stackSize = func.stackSizeCurrent + 1;
    }
    assert(func.stackSizeCurrent >= 0);
}

TodoBlock[] todoBlocks;
size_t[BasicBlock] disabled;
size_t delayed;

struct TodoBlock
{
    BytecodeEmitter emitter;
    BasicBlock block;
    Function newFunc;
    void delegate(ushort) cb;

    this(BytecodeEmitter e, BasicBlock b, Function f, void delegate(ushort) c)
    {
        emitter = e;
        block = b;
        newFunc = f;
        cb = c;
    }

    void opCall()
    {
        size_t delayCount = 0;
        if (size_t* delayCountPtr = block in disabled)
        {
            delayCount = *delayCountPtr;
        }
        if (delayCount != 0)
        {
            foreach (key, ref value; disabled)
            {
                value--;
            }
            delayed++;
            todoBlocks ~= this;
        }
        else
        {
            delayed = 0;
            emitter.entryNew(block, newFunc);
            cb(emitter.counts[block][newFunc]);
        }
    }
}

void enable(BasicBlock bb)
{
    disabled[bb]--;
}

void disable(BasicBlock bb)
{
    if (size_t* ptr = bb in disabled)
    {
        *ptr += 1;
    }
    else
    {
        disabled[bb] = 1;
    }
}

class BytecodeEmitter
{
    BasicBlock[] bbchecked;
    Function func;
    ushort[Function][BasicBlock] counts;
    // TypeGenerator typeGenerator;
    // CodeGenerator codeGenerator;
    bool isFirst = true;

    this()
    {
        // typeGenerator = new TypeGenerator;
        // codeGenerator = new CodeGenerator;
    }

    bool within(BasicBlock block, Function func)
    {
        if (ushort[Function]* tab = block in counts)
        {
            if (func in *tab)
            {
                return true;
            }
            return false;
        }
        else
        {
            return false;
        }
    }

    void entryFunc(BasicBlock block, Function func, string[] args=null)
    {
        bool isBlockFirst = isFirst;
        isFirst = false;
        if (isBlockFirst)
        {
            disabled = null;
        }
        // typeGenerator.startFunction(block, predef(block));
        entryNew(block, func);
        // typeGenerator.stopFunction(block);
        // if (isBlockFirst)
        // {
        //     if (runjit)
        //     {
        //         auto mainfunc = codeGenerator.genMainFunc(block, typeGenerator);
        //         func.jitted = mainfunc;
        //     }
        // }
    }

    void entryNew(BasicBlock block, Function newFunc)
    {
        Function oldFunc = func;
        func = newFunc;
        emit(block);
        func = oldFunc;
        while (todoBlocks.length != 0)
        {
            TodoBlock cur = todoBlocks[0];
            todoBlocks = todoBlocks[1 .. $];
            cur();
        }
    }

    void entry(BasicBlock block, Function newFunc, void delegate(ushort) cb)
    {
        todoBlocks ~= TodoBlock(this, block, newFunc, cb);
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
            if (AssignmentInstruction si = cast(AssignmentInstruction) instr)
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

    void emit(BasicBlock block)
    {
        if (block !in counts)
        {
            counts[block] = null;
        }
        if (!within(block, func))
        {
            // writeln(block);
            // typeGenerator.startBlock(block);
            counts[block][func] = cast(ushort) func.instrs.length;
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
            // typeGenerator.stopBlock(block);
        }
    }

    void emit(Emittable em)
    {
        static foreach (Instr; InstrTypes)
        {
            if (typeid(em) == typeid(Instr))
            {
                // typeGenerator.genFrom(cast(Instr) em);
                emit(cast(Instr) em);
            }
        }
    }

    void emit(LogicalBranch branch)
    {
        pushInstr(func, Opcode.iftrue, [cast(ushort) ushort.max]);
        size_t j0 = func.instrs.length;
        pushInstr(func, Opcode.jump, [cast(ushort) ushort.max]);
        size_t j1 = func.instrs.length;
        Function cfunc = func;
        long remaining = 0;
        void afterLogicalTargets()
        {
            remaining--;
            if (remaining == 0)
            {
                enable(branch.post);
            }
        }
        disable(branch.post);
        remaining++;
        entry(branch.target[0], func, (t0) {
            cfunc.modifyInstr(j0, t0);
            afterLogicalTargets;
        });
        remaining++;
        entry(branch.target[1], func, (t1) {
            cfunc.modifyInstr(j1, t1);
            afterLogicalTargets;
        });
    }

    void emit(GotoBranch branch)
    {
        pushInstr(func, Opcode.jump, [cast(ushort) ushort.max]);
        size_t j0 = func.instrs.length;
        Function cfunc = func;
        entry(branch.target[0], func, (t0) {
            cfunc.modifyInstr(j0, cast(ushort) t0);
        });
    }

    void emit(ReturnBranch branch)
    {
        pushInstr(func, Opcode.retval);
    }

    void emit(BuildArrayInstruction arr)
    {
        pushInstr(func, Opcode.array, [cast(ubyte) arr.argc], cast(int)(1 - arr.argc));
    }

    void emit(BuildTableInstruction table)
    {
        pushInstr(func, Opcode.table, [cast(ubyte) table.argc], cast(int)(1 - table.argc));
    }

    void emit(StoreInstruction store)
    {
        uint ius = func.stab[store.var];
        pushInstr(func, Opcode.store, [cast(ushort) ius]);
    }

    void emit(StoreIndexInstruction store)
    {
        pushInstr(func, Opcode.istore);
    }

    void emit(OperatorStoreInstruction store)
    {
        uint ius = func.stab[store.var];
        pushInstr(func, Opcode.opstore, [
                cast(ushort) ius, cast(ushort) store.op.to!AssignOp
                ]);
    }

    void emit(OperatorStoreIndexInstruction store)
    {
        pushInstr(func, Opcode.opistore, [cast(ushort) store.op.to!AssignOp]);
    }

    void emit(LoadInstruction load)
    {
        bool unfound = true;
        foreach (argno, argname; func.args)
        {
            if (argname.str == load.var)
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

    void emit(CallInstruction call)
    {
        pushInstr(func, Opcode.call, [cast(ushort) call.argc], cast(int)-call.argc);
    }

    void emit(PushInstruction push)
    {
        pushInstr(func, Opcode.push, [cast(ushort) func.constants.length]);
        func.constants ~= push.value;
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
        entryFunc(lambda.entry, newFunc, lambda.argNames.map!(x => x.str).array);
        func.pushInstr(Opcode.sub, [cast(ushort) func.funcs.length]);
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
