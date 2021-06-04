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
    
    void emitInFunc(Bytecode newFunc, BasicBlock block)
    {
    }

    int emit(BasicBlock block)
    {
        return func.bytecode.length;
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
    }

    void emit(GotoBranch branch)
    {
    }

    void emit(ReturnBranch branch)
    {
    }

    void emit(ConstReturnBranch branch)
    {
    }

    void emit(BuildArrayInstruction arr)
    {
    }

    void emit(BuildTupleInstruction arr)
    {
    }

    void emit(BuildTableInstruction table)
    {
    }

    void emit(StoreInstruction store)
    {
    }

    void emit(StoreIndexInstruction store)
    {
    }

    void emit(LoadInstruction load)
    {
    }

    void emit(CallInstruction call)
    {
    }

    void emit(TailCallBranch call)
    {
    }

    void emit(StaticCallInstruction call)
    {
    }

    void emit(PushInstruction push)
    {
    }

    void emit(RecInstruction rec)
    {
    }

    void emit(ArgNumberInstruction argno)
    {
    }

    void emit(InspectInstruction inspect)
    {
    }

    void emit(OperatorInstruction op)
    {
    }

    void emit(ConstOperatorInstruction op)
    {
    }

    void emit(LambdaInstruction lambda)
    {
    }

    void emit(PopInstruction pop)
    {
    }
}
