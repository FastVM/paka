module purr.jit.jit;

import std.stdio;
import std.conv;
import std.array;
import std.algorithm;
import purr.jit.wrapper;
import purr.ir.types;
import purr.ir.repr;
import purr.dynamic;

// jit goes here once types work

TodoBlock[] todoBlocks;
size_t[BasicBlock] disabled;
size_t delayed;

JITRValue pop(ref JITRValue[] values)
{
    JITRValue ret = values[$ - 1];
    values.length--;
    return ret;
}

alias TodoBlock = void delegate();

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

class CodeGenerator
{
    JITContext jitCtx;
    JITFunction jitFunc;
    JITBlock jitBlock;
    BasicBlock currentBlock;
    JITBlock[JITFunction][BasicBlock] counts;
    TypeGenerator typeGenerator;
    JITRValue[] stack;
    JITLValue[string] locals;

    this()
    {
        jitCtx = new JITContext;
        jitCtx.setOption(JITIntOption.OPTIMIZATION_LEVEL, 3);
    }

    size_t funcno = 0;
    string genFuncName()
    {
        string ret = funcno.to!string;
        funcno++;
        return "func_" ~ ret;
    }

    JITType jitTypeOf(Type ty)
    {
        if (typeid(ty) == typeid(Type.Number))
        {
            return jitCtx.getType(JITTypeKind.DOUBLE);
        }
        if (typeid(ty) == typeid(Type.Logical))
        {
            return jitCtx.getType(JITTypeKind.BOOL);
        }
        if (typeid(ty) == typeid(Type.Nil))
        {
            return jitCtx.getType(JITTypeKind.BOOL);
        }
        if (Type.Options opts = cast(Type.Options) ty)
        {
            assert(opts.options.length == 1, opts.options.to!string);
            return jitTypeOf(opts.options[0]);
            // return jitCtx.getType(JITTypeKind.DOUBLE);
        }
        assert(false, ty.to!string);
    }

    double function() genMainFunc(BasicBlock block, TypeGenerator tg, string[] predef)
    {
        typeGenerator = tg;
        Type.Function funcType = typeGenerator.blockTypes[block];
        JITType jitRetType = jitTypeOf(funcType.retn);
        JITType[] jitParamTypes = null;
        jitFunc = jitCtx.newFunction(JITFunctionKind.EXPORTED, jitRetType, "main", false);
        foreach (sym; predef)
        {
            locals[sym] = jitFunc.newLocal(jitTypeOf(tg.localsAt[block][sym]), sym);
        }
        emit(block);
        while (todoBlocks.length != 0)
        {
            TodoBlock cur = todoBlocks[0];
            todoBlocks = todoBlocks[1 .. $];
            cur();
        }
        JITResult jitResult = jitCtx.compile;
        void* vptr = jitResult.getCode("main");
        double function() res = cast(double function()) vptr;
        return res;
        // writeln("jit says: ", res());
    }

    void genFunc(BasicBlock block)
    {
        assert(false);
    }

    bool within(BasicBlock block, JITFunction func)
    {
        if (JITBlock[JITFunction]* tab = block in counts)
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

    void emit(BasicBlock block)
    {
        if (block !in counts)
        {
            counts[block] = null;
        }
        if (!within(block, jitFunc))
        {
            currentBlock = block;
            JITBlock myJitBlock = jitFunc.newBlock(block.name);
            counts[block][jitFunc] = myJitBlock;
            jitBlock = myJitBlock;
            foreach (instr; block.instrs)
            {
                emitAnyEmittable(instr);
            }
            emitAnyEmittable(block.exit);
        }
    }

    void emitAnyEmittable(Emittable em)
    {
        static foreach (Instr; InstrTypes)
        {
            if (typeid(em) == typeid(Instr))
            {
                emit(cast(Instr) em);
            }
        }
    }

    void emit(Instr)(Instr branch)
    {
        assert(false, Instr.stringof);
    }

    void emit(OperatorInstruction op)
    {
        final switch (op.op)
        {
        case "mul":
            JITRValue rhs = stack.pop;
            JITRValue lhs = stack.pop;
            stack ~= jitCtx.newBinaryOp(JITBinaryOp.MULT,
                    jitCtx.getType(JITTypeKind.DOUBLE), lhs, rhs);
            break;
        case "div":
            JITRValue rhs = stack.pop;
            JITRValue lhs = stack.pop;
            stack ~= jitCtx.newBinaryOp(JITBinaryOp.DIVIDE,
                    jitCtx.getType(JITTypeKind.DOUBLE), lhs, rhs);
            break;
        case "mod":
            JITRValue rhs = stack.pop;
            JITRValue lhs = stack.pop;
            JITFunction fmod = jitCtx.getBuiltinFunction("fmod");
            stack ~= jitCtx.newCall(fmod, [lhs, rhs]);
            break;
        case "sub":
            JITRValue rhs = stack.pop;
            JITRValue lhs = stack.pop;
            stack ~= jitCtx.newBinaryOp(JITBinaryOp.MINUS,
                    jitCtx.getType(JITTypeKind.DOUBLE), lhs, rhs);
            break;
        case "add":
            JITRValue rhs = stack.pop;
            JITRValue lhs = stack.pop;
            stack ~= jitCtx.newBinaryOp(JITBinaryOp.PLUS,
                    jitCtx.getType(JITTypeKind.DOUBLE), lhs, rhs);
            break;
        case "lt":
            JITRValue rhs = stack.pop;
            JITRValue lhs = stack.pop;
            stack ~= jitCtx.newComparison(JITComparison.LT, lhs, rhs);
            break;
        case "gt":
            JITRValue rhs = stack.pop;
            JITRValue lhs = stack.pop;
            stack ~= jitCtx.newComparison(JITComparison.GT, lhs, rhs);
            break;
        case "lte":
            JITRValue rhs = stack.pop;
            JITRValue lhs = stack.pop;
            stack ~= jitCtx.newComparison(JITComparison.LE, lhs, rhs);
            break;
        case "gte":
            JITRValue rhs = stack.pop;
            JITRValue lhs = stack.pop;
            stack ~= jitCtx.newComparison(JITComparison.GE, lhs, rhs);
            break;
        case "eq":
            JITRValue rhs = stack.pop;
            JITRValue lhs = stack.pop;
            stack ~= jitCtx.newComparison(JITComparison.EQ, lhs, rhs);
            break;
        case "neq":
            JITRValue rhs = stack.pop;
            JITRValue lhs = stack.pop;
            stack ~= jitCtx.newComparison(JITComparison.NE, lhs, rhs);
            break;
        }
    }

    void emit(LoadInstruction load)
    {
        stack ~= locals[load.var];
    }

    void emit(StoreInstruction store)
    {
        jitBlock.addAssignment(locals[store.var], stack[$ - 1]);
    }

    void emit(PopInstruction _)
    {
        stack.pop;
    }

    void emit(PushInstruction push)
    {
        Dynamic val = push.value;
        switch (val.type)
        {
        case Dynamic.Type.nil:
            stack ~= jitCtx.newRValue(jitCtx.getType(JITTypeKind.BOOL), false);
            break;
        case Dynamic.Type.log:
            stack ~= jitCtx.newRValue(jitCtx.getType(JITTypeKind.BOOL), val.log);
            break;
        case Dynamic.Type.sml:
            stack ~= jitCtx.newRValue(jitCtx.getType(JITTypeKind.DOUBLE), val.as!double);
            break;
        case Dynamic.Type.str:
            assert(false);
        default:
            assert(false);
        }
    }

    void entry(BasicBlock block, void delegate(JITBlock) cb)
    {
        JITFunction myFunc = jitFunc;
        todoBlocks ~= {
            JITFunction oldJitFunc = jitFunc;
            jitFunc = myFunc;
            emit(block);
            jitFunc = oldJitFunc;
            cb(counts[block][oldJitFunc]);
        };
    }

    void emit(ReturnBranch retb)
    {
        jitBlock.endWithReturn(stack.pop);
    }

    void emit(GotoBranch retb)
    {
        JITBlock myJitBlock = jitBlock;
        entry(retb.target[0], (t0) { myJitBlock.endWithJump(t0); });
    }

    void emit(LogicalBranch logb)
    {
        BasicBlock bb = currentBlock;
        JITBlock myJitBlock = jitBlock;
        JITRValue cond = stack.pop;
        entry(logb.target[0], (iftrue) {
            entry(logb.target[1], (iffalse) {
                myJitBlock.endWithConditional(cond, iftrue, iffalse);
            });
        });
    }
}
