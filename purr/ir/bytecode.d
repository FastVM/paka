module purr.ir.bytecode;

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
import purr.ir.repr;
import purr.type.check;

int add(Bytecode func, int val)
{
    int where = cast(int) func.bytecode.length;
    func.bytecode.push(val);
    return where;
}

void set(Bytecode func, int where, int val)
{
    func.bytecode.index!int(where) = val;
}

int length(Bytecode func)
{
    return cast(int) func.bytecode.length;
}

final class BytecodeEmitter
{
    BasicBlock[] bbchecked;
    Bytecode func;
    Opt opt;
    TypeChecker tc;
    string[][] locals = [null];
    string[][] args = [null];

    this()
    {
        opt = new Opt;
        tc = new TypeChecker;
    }

    int depth()
    {
        return cast(int) locals.length;
    }

    void emitInFunc(Bytecode newFunc, BasicBlock block)
    {
        Bytecode lastFunc = func;
        func = newFunc;
        scope (exit)
        {
            func = lastFunc;
        }
        emit(block);
    }

    int emit(BasicBlock block)
    {
        if (block.place < 0)
        {
            block.place = cast(int) func.bytecode.length;
            if (dumpir)
            {
                writeln(block);
            }
            foreach (instr; block.instrs)
            {
                emit(instr);
            }
            emit(block.exit);
        }
        return block.place;
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
        if (branch.target[0].place < 0)
        {
            func.add(Opcode.iffalse);
            int iffalse = func.add(-1);
            emit(branch.target[0]);
            func.add(Opcode.jump);
            int jout = func.add(-1);
            int next = emit(branch.target[1]);
            func.set(iffalse, next);
            func.set(jout, func.length);
        }
        else
        {
            assert(false, "not implemented");
        }
        assert(branch.target[0].place > 0);
        assert(branch.target[1].place > 0);
    }

    void emit(GotoBranch branch)
    {
        if (branch.target[0].place < 0)
        {
            emit(branch.target[0]);
        }
        else
        {
            func.add(Opcode.jump);
            int jump = func.add(-1);
            int to = emit(branch.target[0]);
            func.set(jump, to);
        }
    }

    void emit(ReturnBranch branch)
    {
        if (depth > 1)
        {
            func.add(Opcode.ret);
        }
        else
        {
            func.add(Opcode.exit);
        }
    }

    void emit(ConstReturnBranch branch)
    {
        func.add(Opcode.push);
        func.add(cast(int) func.constants.length);
        func.constants.push(branch.value);
        if (depth > 1)
        {
            func.add(Opcode.ret);
        }
        else
        {
            func.add(Opcode.exit);
        }
    }

    // void emit(BuildArrayInstruction arr)
    // {
    //     assert(false, "not implemented");
    // }

    // void emit(BuildTupleInstruction arr)
    // {
    //     assert(false, "not implemented");
    // }

    // void emit(BuildTableInstruction table)
    // {
    //     assert(false, "not implemented");
    // }

    void emit(StoreInstruction store)
    {
        foreach (k, v; locals[$ - 1])
        {
            if (v == store.var)
            {
                func.add(Opcode.store);
                func.add(cast(int) k);
                return;
            }
        }
        int index = cast(int) locals[$ - 1].length;
        locals[$ - 1] ~= store.var;
        func.add(Opcode.store);
        func.add(index);
    }

    void emit(StoreIndexInstruction store)
    {
        assert(false, "not implemented");
    }

    void emit(LoadInstruction load)
    {
        foreach (key, arg; args[$ - 1])
        {
            if (arg == load.var)
            {
                func.add(Opcode.arg);
                func.add(cast(int) key);
                return;
            }
        }

        foreach (k, v; locals[$ - 1])
        {
            if (v == load.var)
            {
                func.add(Opcode.load);
                func.add(cast(int) k);
                return;
            }
        }

        func.add(Opcode.loadc);
        Bytecode cur = func;
        int index = depth - 1;
        while (index > 0)
        {
            assert(cur !is null);
            index--;
            foreach (key, local; locals[index])
            {
                if (local == load.var)
                {
                    func.add(cast(int) cur.captureFrom.length);
                    cur.captureFrom.push!int(cast(int) key);
                    cur.captureFlags.push!int(Capture.local);
                    return;
                }
            }
            foreach (key, arg; args[index])
            {
                if (arg == load.var)
                {
                    func.add(cast(int) cur.captureFrom.length);
                    cur.captureFrom.push!int(cast(int) key);
                    cur.captureFlags.push!int(Capture.arg);
                    return;
                }
            }
            cur.captureFrom.push!int(cast(int) cur.parent.captureFrom.length);
            cur.captureFlags.push!int(Capture.parent);
            cur = cur.parent;
        }
        assert(false);
    }

    void emit(CallInstruction call)
    {
        func.add(Opcode.call);
        func.add(call.argc);
    }

    void emit(TailCallBranch call)
    {
        func.add(Opcode.call);
        func.add(call.argc);
        if (depth > 1)
        {
            func.add(Opcode.ret);
        }
        else
        {
            func.add(Opcode.exit);
        }
    }

    void emit(StaticCallInstruction call)
    {
        assert(false, "not implemented");
    }

    void emit(PushInstruction push)
    {
        func.add(Opcode.push);
        func.add(cast(int) func.constants.length);
        func.constants.push(push.value);
    }

    void emit(RecInstruction rec)
    {
        func.add(Opcode.rec);
        func.add(rec.argc);
    }

    void emit(ArgNumberInstruction argno)
    {
        func.add(Opcode.arg);
        func.add(argno.argno);
    }

    void emit(OperatorInstruction op)
    {
        switch (op.op)
        {
        default:
            assert(false, "not implemented " ~ op.op);
        case "add":
            func.add(Opcode.add);
            break;
        case "sub":
            func.add(Opcode.sub);
            break;
        case "mul":
            func.add(Opcode.mul);
            break;
        case "div":
            func.add(Opcode.div);
            break;
        case "lt":
            func.add(Opcode.lt);
            break;
        case "gt":
            func.add(Opcode.gt);
            break;
        case "lte":
            func.add(Opcode.lte);
            break;
        case "gte":
            func.add(Opcode.gte);
            break;
        case "eq":
            func.add(Opcode.eq);
            break;
        case "neq":
            func.add(Opcode.neq);
            break;
        }
    }

    void emit(ConstOperatorInstruction op)
    {
        func.add(Opcode.push);
        func.add(cast(int) func.constants.length);
        func.constants.push(op.rhs);
        switch (op.op)
        {
        default:
            assert(false, "not implemented " ~ op.op);
        case "add":
            func.add(Opcode.add);
            break;
        case "sub":
            func.add(Opcode.sub);
            break;
        case "mul":
            func.add(Opcode.mul);
            break;
        case "div":
            func.add(Opcode.div);
            break;
        case "lt":
            func.add(Opcode.lt);
            break;
        case "gt":
            func.add(Opcode.gt);
            break;
        case "lte":
            func.add(Opcode.lte);
            break;
        case "gte":
            func.add(Opcode.gte);
            break;
        case "eq":
            func.add(Opcode.eq);
            break;
        case "neq":
            func.add(Opcode.neq);
            break;
        }
    }

    void emit(LambdaInstruction lambda)
    {
        locals.length++;
        args ~= lambda.argNames;
        scope (exit)
        {
            locals.length--;
            args.length--;
        }
        Bytecode newFunc = Bytecode.from(func);
        emitInFunc(newFunc, lambda.entry);
        func.add(Opcode.push);
        func.add(cast(int) func.constants.length);
        func.constants.push(newFunc.dynamic);
        func.add(Opcode.func);
    }

    void emit(PopInstruction pop)
    {
        func.add(Opcode.pop);
    }

    void emit(PrintInstruction print)
    {
        func.add(Opcode.print);
    }
}
