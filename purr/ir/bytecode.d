module purr.ir.bytecode;

import core.memory;
import std.conv;
import std.array;
import std.string;
import std.algorithm;
import std.typecons;
import std.meta;
import purr.io;
import purr.srcloc;
import purr.vm.bytecode;
import purr.inter;
import purr.ir.opt;
import purr.ir.repr;
import purr.type.repr;

int add(Bytecode func, ubyte ub)
{
    int where = func.bytecodeLength++;
    *cast(ubyte*)&func.bytecode[where] = ub;
    return where;
}

int add(Bytecode func, int val)
{
    int where = func.bytecodeLength;
    ubyte[int.sizeof] ubs = *cast(ubyte[int.sizeof]*)&val;
    foreach (ub; ubs)
    {
        func.add(ub);
    }
    return where;
}

int add(Bytecode func, void[] vals)
{
    int where = func.bytecodeLength;
    foreach (ubyte val; cast(ubyte[]) vals)
    {
        func.add(val);
    }
    return where;
}

void set(Bytecode func, int where, void[] vals)
{
    foreach (index, val; cast(ubyte[]) vals)
    {
        *cast(ubyte*)&func.bytecode[where + index] = val;
    }
}

void set(Bytecode func, int where, int val)
{
    *cast(int*)&func.bytecode[where] = val;
}

int length(Bytecode func)
{
    return cast(int) func.bytecodeLength;
}

final class BytecodeEmitter
{
pragma(inline, false):
    BasicBlock[] bbchecked;
    Bytecode func;
    Opt opt;
    int[string][] locals = [null];
    int[] offsets = [0];
    int[string][] args = [null];

    this()
    {
        opt = new Opt;
    }

    int depth()
    {
        return cast(int) locals.length;
    }

    void emitInFunc(Bytecode newFunc, BasicBlock block)
    {
        opt.opt(block);
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
            block.place = cast(int) func.bytecodeLength;
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

    void emit(LabelBranch branch)
    {
        func.add(Opcode.ec_cons);
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

    void emit(JumpBranch branch)
    {
        func.add(Opcode.ec_call);
    }

    void emit(ReturnBranch branch)
    {
        if (depth <= 1)
        {
            func.add(Opcode.exit);
        }
        else
        {
            if (branch.type.isUnk)
            {
                branch.type.getUnk.set(Type.nil);
            }
            final switch (branch.type.size)
            {
            case 0:
                func.add(Opcode.return_nil);
                break;
            case 1:
                func.add(Opcode.return1);
                break;
            case 2:
                func.add(Opcode.return2);
                break;
            case 4:
                func.add(Opcode.return4);
                break;
            case 8:
                func.add(Opcode.return8);
                break;
            }
        }
    }

    void emit(StoreInstruction store)
    {
        // if (!store.type.runtime)
        // {
        //     return;
        // }
        int data;
        if (int* pdata = store.var in locals[$ - 1])
        {
            data = *pdata;
        }
        else
        {
            data = offsets[$ - 1];
            locals[$ - 1][store.var] = data;
            offsets[$ - 1] += store.type.size;
        }
        final switch (store.type.size)
        {
        case 0:
            break;
        case 1:
            func.add(Opcode.store1);
            func.add(data);
            break;
        case 2:
            func.add(Opcode.store2);
            func.add(data);
            break;
        case 4:
            func.add(Opcode.store4);
            func.add(data);
            break;
        case 8:
            func.add(Opcode.store8);
            func.add(data);
            break;
        }
    }

    void emit(StoreIndexInstruction store)
    {
        assert(false, "not implemented");
    }

    void emit(LoadInstruction load)
    {
        // if (!load.type.runtime)
        // {
        //     return;
        // }
        if (int* pdata = load.var in locals[$ - 1])
        {
            int data = *pdata;
            final switch (load.type.size)
            {
            case 0:
                break;
            case 1:
                func.add(Opcode.load1);
                func.add(data);
                break;
            case 2:
                func.add(Opcode.load2);
                func.add(data);
                break;
            case 4:
                func.add(Opcode.load4);
                func.add(data);
                break;
            case 8:
                func.add(Opcode.load8);
                func.add(data);
                break;
            }
        }
        else if (int * parg = load.var in args[$ - 1])
        {
            int arg =  * parg;
            final switch (load.type.size)
            {
            case 0 : break;
            case 1 : func.add(Opcode.arg1);
                func.add(arg);
                break;
            case 2 : func.add(Opcode.arg2);
                func.add(arg);
                break;
            case 4 : func.add(Opcode.arg4);
                func.add(arg);
                break;
            case 8 : func.add(Opcode.arg8);
                func.add(arg);
                break;
            }

            return;
        }
        else if (load.type.runtime)
        {
            throw new Exception("variable not found: " ~ load.var);
        }
    }

    void emit(CallInstruction call)
    {
        Type basety = call.func;
        if (Generic generic = call.func.as!Generic)
        {
            basety = generic.specialize(call.args);
        }
        Func functy = basety.as!Func;
        if (functy is null)
        {
            throw new Exception("cannot call: " ~ call.func.to!string);
        }
        int argc = 0;
        foreach(argno, expected; functy.args)
        {
            // if (!call.args[argno].runtime || expected.fits(call.args[argno]))
            // {
                argc += expected.size;
            // }
        }
        if (functy.impl is null)
        {
            func.add(Opcode.call);
            func.add(argc);
        }
        else
        {
            func.add(Opcode.call_static);
            func.add(argc);
            void[Bytecode.sizeof] arr = *cast(void[Bytecode.sizeof]*)&functy.impl;
            func.add(arr.dup);
        }
    }

    void emit(PushInstruction push)
    {
        final switch (push.res.size)
        {
        case 0:
            break;
        case 1:
            func.add(Opcode.push1);
            func.add(push.value);
            break;
        case 2:
            func.add(Opcode.push2);
            func.add(push.value);
            break;
        case 4:
            func.add(Opcode.push4);
            func.add(push.value);
            break;
        case 8:
            func.add(Opcode.push8);
            func.add(push.value);
            break;
        }
    }

    void emit(RecInstruction rec)
    {
        func.add(Opcode.rec);
        func.add(rec.argc);
    }

    void emit(OperatorInstruction op)
    {
        if (op.inputTypes.length == 2)
        {
            if (op.inputTypes[0].isUnk)
            {
                op.inputTypes[0].getUnk.set(op.inputTypes[1]);
            }
            if (op.inputTypes[1].isUnk)
            {
                op.inputTypes[1].getUnk.set(op.inputTypes[0]);
            }
            if (!op.inputTypes[0].fits(op.inputTypes[1]))
            {
                throw new Exception("type error in " ~ op.op ~ ": " ~ op.inputTypes[0].to!string ~ " vs " ~ op.inputTypes[1].to!string);
            }
            if (op.resType.isUnk)
            {
                if (numops.canFind(op.op))
                {
                    op.resType.getUnk.set(op.inputTypes[0]);
                }
                if (logicops.canFind(op.op))
                {
                    op.resType.getUnk.set(Type.logical);
                }
            }
        }
        switch (op.op)
        {
        default:
            assert(false, "not implemented " ~ op.op);
        case "add":
            if (op.resType.fits(Type.integer))
            {
                func.add(Opcode.add_integer);
            }
            else
            {
                func.add(Opcode.add_float);
            }
            break;
        case "sub":
            if (op.resType.fits(Type.integer))
            {
                func.add(Opcode.sub_integer);
            }
            else
            {
                func.add(Opcode.sub_float);
            }
            break;
        case "mul":
            if (op.resType.fits(Type.integer))
            {
                func.add(Opcode.mul_integer);
            }
            else
            {
                func.add(Opcode.mul_float);
            }
            break;
        case "div":
            if (op.resType.fits(Type.integer))
            {
                func.add(Opcode.div_integer);
            }
            else
            {
                func.add(Opcode.div_float);
            }
            break;
        case "lt":
            if (op.resType.fits(Type.integer))
            {
                func.add(Opcode.lt_integer);
            }
            else
            {
                func.add(Opcode.lt_float);
            }
            break;
        case "gt":
            if (op.resType.fits(Type.integer))
            {
                func.add(Opcode.gt_integer);
            }
            else
            {
                func.add(Opcode.gt_float);
            }
            break;
        case "lte":
            if (op.resType.fits(Type.integer))
            {
                func.add(Opcode.lte_integer);
            }
            else
            {
                func.add(Opcode.lte_float);
            }
            break;
        case "gte":
            if (op.resType.fits(Type.integer))
            {
                func.add(Opcode.gte_integer);
            }
            else
            {
                func.add(Opcode.gte_float);
            }
            break;
        case "eq":
            if (op.resType.fits(Type.integer))
            {
                func.add(Opcode.eq_integer);
            }
            else
            {
                func.add(Opcode.eq_float);
            }
            break;
        case "neq":
            if (op.resType.fits(Type.integer))
            {
                func.add(Opcode.neq_integer);
            }
            else
            {
                func.add(Opcode.neq_float);
            }
            break;
        case "not":
            func.add(Opcode.not);
            break;
        }
    }

    void emit(LambdaInstruction lambda)
    {
        locals.length++;
        offsets.length++;
        int argoffset = 0;
        int[string] cargs;
        foreach (argname; lambda.args)
        {
            Type argty = lambda.types[argname];
            cargs[argname] = argoffset;
            // if (!argty.isUnk)
            // {
            argoffset += argty.size;
            // }
        }
        args ~= cargs;
        scope (exit)
        {
            locals.length--;
            args.length--;
            offsets.length--;
        }
        Bytecode newFunc = lambda.impl;
        emitInFunc(newFunc, lambda.entry);
        // func.add(Opcode.push8);
        // func.add(*cast(void[size_t.sizeof]*)&newFunc);
    }

    void emit(PopInstruction pop)
    {
        // if (!pop.type.runtime)
        // {
        //     return;
        // }
        size_t size = pop.type.size;
        while (size >= 8)
        {
            func.add(Opcode.pop8);
            size -= 8;
        }
        if (size >= 4)
        {
            func.add(Opcode.pop4);
            size -= 4;
        }
        if (size >= 2)
        {
            func.add(Opcode.pop2);
            size -= 2;
        }
        if (size >= 1)
        {
            func.add(Opcode.pop1);
            size -= 1;
        }
        assert(size == 0);
    }

    void emit(PrintInstruction print)
    {
        if (print.type.fits(Type.integer))
        {
            func.add(Opcode.print_integer);
        }
        else if (print.type.fits(Type.float_))
        {
            func.add(Opcode.print_float);
        }
        else if (print.type.fits(Type.text))
        {
            func.add(Opcode.print_text);
        }
        else if (Higher higher = print.type.as!Higher)
        {
            Type boxed = higher.type;
            func.add(Opcode.push8);
            immutable(char)* typename = "?".toStringz;
            int loc = func.add(*cast(void[size_t.sizeof]*)&typename);
            boxed.then((Known kn) {
                immutable(char)* typename = kn.to!string.toStringz;
                func.set(loc, *cast(void[size_t.sizeof]*)&typename);
            });
            func.add(Opcode.print_text);
        }
        else
        {
            throw new Exception("cannot print value of type: " ~ print.type.to!string);
        }
    }
}
