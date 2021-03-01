module purr.jit.jit;

import core.memory;
import std.stdio;
import std.conv;
import std.array;
import std.string;
import std.algorithm;
import purr.jit.other;
import purr.jit.wrapper;
import purr.ir.types;
import purr.ir.repr;
import purr.dynamic;
import purr.base;

int optlevel = 2;

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

class Local
{
    JITLValue value;
    JITType type;
    string name;

    this(JITLValue v, JITType t, string n)
    {
        value = v;
        type = t;
        name = n;
    }
}

void* paka_gc_malloc(size_t size)
{
    import core.stdc.stdlib;

    return GC.malloc(size);
}

class CodeGenerator
{
    JITContext jitCtx;
    JITFunction jitFunc;
    JITFunction jitFuncFirst;
    JITBlock jitBlock;
    JITRValue jitClosure;
    TypeGenerator typeGenerator;
    BasicBlock currentBlock;
    JITRValue[] stack;
    Local[string] locals;
    JITBlock[JITFunction][BasicBlock] counts;

    JITField funcptr;
    JITField dataptr;
    JITStruct closureType;

    this()
    {
        jitCtx = new JITContext;
        funcptr = jitCtx.newField(jitCtx.newFunctionType(bytePtr, false), "funcptr");
        dataptr = jitCtx.newField(bytePtr, "dataptr");
        closureType = jitCtx.newStructType("_paka_closure_type", [
                funcptr, dataptr
                ]);
    }

    JITType bytePtr()
    {
        return jitCtx.getType(JITTypeKind.UNSIGNED_CHAR).pointerOf;
    }

    JITType numberType()
    {
        // return jitCtx.getType(JITTypeKind.LONG);
        return jitCtx.getType(JITTypeKind.DOUBLE);
    }

    JITRValue consNumber(T)(T v)
    {
        return jitCtx.newRValue(numberType, v.to!double);
    }

    size_t funcno = 0;
    string genFuncName()
    {
        string ret = funcno.to!string;
        funcno++;
        return "func_" ~ ret;
    }

    size_t closureno = 0;
    string genClosureName()
    {
        string ret = closureno.to!string;
        closureno++;
        return "clousre_" ~ ret;
    }

    size_t tmpvarno = 0;
    string genTmpVar()
    {
        string ret = tmpvarno.to!string;
        tmpvarno++;
        return "var_" ~ ret;
    }

    JITType jitTypeOf(Type ty)
    {
        if (typeid(ty) == typeid(Type.Number))
        {
            return numberType;
        }
        if (typeid(ty) == typeid(Type.Logical))
        {
            return jitCtx.getType(JITTypeKind.UNSIGNED_CHAR);
        }
        if (typeid(ty) == typeid(Type.Nil))
        {
            return jitCtx.getType(JITTypeKind.UNSIGNED_CHAR);
        }
        if (typeid(ty) == typeid(Type.Table))
        {
            return bytePtr;
        }
        if (typeid(ty) == typeid(Type.Function))
        {
            return closureType;
        }
        if (Type.Options opts = cast(Type.Options) ty)
        {
            if (opts.options.length == 0)
            {
                throw new Exception("jit is broken for this code");
            }
            if (opts.options.length > 1)
            {
                throw new Exception("jit is broken for this code, debug: " ~ opts.to!string);
            }
            return jitTypeOf(opts.options[0]);
        }
        assert(false, ty.to!string);
    }

    Local newLocal(JITType ty, string sym)
    {
        Local ret = new Local(jitFunc.newLocal(ty, sym), ty, sym);
        locals[sym] = ret;
        return ret;
    }

    void function() genMainFunc(BasicBlock block, TypeGenerator tg)
    {
        jitCtx.setOption(JITIntOption.OPTIMIZATION_LEVEL, optlevel);
        typeGenerator = tg;
        Type.Function funcType = typeGenerator.blockTypes[block];
        JITType jitRetType = jitCtx.getType(JITTypeKind.VOID);
        jitFunc = jitFuncFirst = jitCtx.newFunction(JITFunctionKind.EXPORTED,
                jitRetType, "main", false);
        foreach (sym, ty; tg.localsAt[block])
        {
            locals[sym] = newLocal(jitTypeOf(ty), sym);
        }
        foreach (sym, ty; loadBaseTypes)
        {
            if (ty.options.length != 0)
            {
                locals[sym] = newLocal(jitTypeOf(ty), sym);
            }
        }
        emit(block);
        while (todoBlocks.length != 0)
        {
            TodoBlock cur = todoBlocks[0];
            todoBlocks = todoBlocks[1 .. $];
            cur();
        }
        gcc_jit_context_compile_to_file(jitCtx.getContext(),
                GCC_JIT_OUTPUT_KIND_ASSEMBLER, "out.s".ptr);
        jitFunc.dump("out.txt");
        JITResult jitResult = jitCtx.compile;
        void* vptr = jitResult.getCode("main");
        void function() res = cast(void function()) vptr;
        return res;
    }

    JITRValue newJitClosure()
    {
        assert(false);
    }

    JITRValue genFunc(BasicBlock block, string[] argnames)
    {
        Local[string] lastLocals = locals;
        JITBlock lastJitBlock = jitBlock;
        TodoBlock[] lastTodoBlocks = todoBlocks;
        locals = null;
        Type.Function funcType = typeGenerator.blockTypes[block];
        JITType jitRetType = jitTypeOf(funcType.retn);
        JITType[] jitParamTypes;
        foreach (key, type; funcType.args.exact)
        {
            foreach (_; jitParamTypes.length .. key + 1)
            {
                jitParamTypes ~= jitCtx.getType(JITTypeKind.UNSIGNED_CHAR);
            }
            jitParamTypes[key] = jitTypeOf(type);
        }
        JITParam[] jitParams;
        foreach (key; 0 .. argnames.length)
        {
            jitParams ~= jitCtx.newParam(jitParamTypes[key], argnames[key]);
        }
        jitParams ~= jitCtx.newParam(bytePtr, "_paka_closure");
        JITFunction lastJitFunc = jitFunc;
        string funcName = genFuncName;
        JITFunction curJitFunc = jitFunc = jitCtx.newFunction(JITFunctionKind.EXPORTED,
                jitRetType, funcName, false, jitParams);
        foreach (key; 0 .. argnames.length)
        {
            locals[argnames[key]] = new Local(curJitFunc.getParam(cast(int) key),
                    jitParamTypes[key], argnames[key]);
        }
        foreach (sym, ty; typeGenerator.localsAt[block])
        {
            locals[sym] = newLocal(jitTypeOf(ty), sym);
        }
        JITRValue closure = curJitFunc.getParam(cast(int)(jitParams.length - 1));
        JITType offsetType = jitCtx.getType(JITTypeKind.SIZE_T);
        JITRValue curOffset = jitCtx.zero(offsetType);
        JITRValue alloc = jitCtx.newRValue(mallocFunction, &paka_gc_malloc);
        JITRValue[string] closureIndex;
        foreach (sym, ty; typeGenerator.capturesAt[block])
        {
            JITType type = jitTypeOf(ty).pointerOf;
            JITRValue rval = jitCtx.newArrayAccess(closure, curOffset).getAddress;
            locals[sym] = new Local(rval.castTo(type.pointerOf).dereference.dereference, type, sym);
            closureIndex[sym] = curOffset;
            curOffset = jitCtx.newBinaryOp(JITBinaryOp.PLUS, offsetType,
                    curOffset, jitCtx.getSizeOf(type));
        }
        JITLValue cvar = lastJitFunc.newLocal(bytePtr, funcName ~ "_closure");
        lastJitBlock.addAssignment(cvar, jitCtx.newCall(alloc, curOffset));
        foreach (sym, ty; typeGenerator.capturesAt[block])
        {
            JITType type = jitTypeOf(ty).pointerOf;
            JITRValue rval = jitCtx.newArrayAccess(cvar, closureIndex[sym]).getAddress;
            JITLValue symvar = rval.castTo(type.pointerOf).dereference;
            if (Local* localPtr = sym in lastLocals)
            {
                lastJitBlock.addAssignment(symvar, localPtr.value.getAddress);
            }
            else
            {
                throw new Exception("internal error in closure");
            }
        }
        todoBlocks = null;
        emit(block);
        while (todoBlocks.length != 0)
        {
            TodoBlock cur = todoBlocks[0];
            todoBlocks = todoBlocks[1 .. $];
            cur();
        }
        todoBlocks = lastTodoBlocks;
        jitFunc = lastJitFunc;
        jitBlock = lastJitBlock;
        locals = lastLocals;
        JITLValue lval = lastJitFunc.newLocal(closureType, genClosureName ~ "_closure");
        JITType voidfunc = jitCtx.newFunctionType(bytePtr, false);
        lastJitBlock.addAssignment(lval.accessField(funcptr),
                curJitFunc.getAddress.castTo(voidfunc));
        lastJitBlock.addAssignment(lval.accessField(dataptr), cvar);
        curJitFunc.dump("out." ~ funcName ~ ".txt");
        return lval;
    }

    JITType mallocFunction()
    {
        return jitCtx.newFunctionType(bytePtr, false, [
                jitCtx.getType(JITTypeKind.SIZE_T)
                ]);
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

    void delegate()[BasicBlock] callBeforeClose;

    JITBlock emitFirst(BasicBlock block)
    {
        currentBlock = block;
        JITBlock myJitBlock = jitFunc.newBlock(block.name);
        counts[block][jitFunc] = myJitBlock;
        jitBlock = myJitBlock;
        foreach (instr; block.instrs)
        {
            emitAnyEmittable(instr);
        }
        if (void delegate()* fun = block in callBeforeClose)
        {
            (*fun)();
        }
        emitAnyEmittable(block.exit);
        return myJitBlock;
    }

    JITBlock emit(BasicBlock block)
    {
        if (block !in counts)
        {
            counts[block] = null;
        }
        if (!within(block, jitFunc))
        {
            counts[block][jitFunc] = emitFirst(block);
        }
        return counts[block][jitFunc];
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

    JITRValue callClosure(JITType retn, JITRValue func, JITRValue[] args)
    {
        JITType[] argTypes;
        foreach (arg; args)
        {
            argTypes ~= arg.getType;
        }
        argTypes ~= bytePtr;
        JITType funcType = jitCtx.newFunctionType(retn, false, argTypes);
        return jitCtx.newCall(func.accessField(funcptr).castTo(funcType),
                args ~ func.accessField(dataptr));
        // return jitCtx.newCall(func, args);
    }

    void emit(LambdaInstruction lambda)
    {
        JITRValue func = genFunc(lambda.entry, lambda.argNames.map!(x => x.str).array);
        stack ~= func;
    }

    void emit(OperatorStoreInstruction opstore)
    {
        emitOpStoreBinary(opstore.var, opstore.op);
    }

    void emitOpStoreBinary(string var, string op)
    {
        final switch (op)
        {
        case "mul":
            jitBlock.addAssignmentOp(locals[var].value, JITBinaryOp.MULT, stack[$ - 1]);
            break;
        case "div":
            jitBlock.addAssignmentOp(locals[var].value, JITBinaryOp.DIVIDE, stack[$ - 1]);
            break;
        case "mod":
            // Double
            JITFunction fmod = jitCtx.getBuiltinFunction("fmod");
            JITRValue rvalue = jitCtx.newCall(fmod, [locals[var].value, stack[$ - 1]]);
            jitBlock.addAssignment(locals[var].value, rvalue);
            // // Integer.value
            // jitBlock.addAssignmentOp(locals[var].value, JITBinaryOp.MODULO, stack[$ - 1]);
            break;
        case "sub":
            jitBlock.addAssignmentOp(locals[var].value, JITBinaryOp.MINUS, stack[$ - 1]);
            break;
        case "add":
            jitBlock.addAssignmentOp(locals[var].value, JITBinaryOp.PLUS, stack[$ - 1]);
            break;
        case "lt":
        case "gt":
        case "lte":
        case "gte":
        case "eq":
        case "neq":
            assert(false);
        }
        stack[$ - 1] = locals[var].value;
    }

    void emitOpBinary(string op)
    {
        final switch (op)
        {
        case "index":
            // JITRValue rhs = stack.pop;
            // JITRValue lhs = stack.pop;
            // JITFunction fmod = jitCtx.getBuiltinFunction("fmod");
            // stack ~= jitCtx.newCall(fmod, [lhs, rhs]);
            // JITFunction fmod = jitCtx.getBuiltinFunction("printf");
            // stack ~= new jitCtx.newCall()
            assert(false, "internal error: not implemented yet: x[y]");
        case "mul":
            JITRValue rhs = stack.pop;
            JITRValue lhs = stack.pop;
            stack ~= jitCtx.newBinaryOp(JITBinaryOp.MULT, numberType, lhs, rhs);
            break;
        case "div":
            JITRValue rhs = stack.pop;
            JITRValue lhs = stack.pop;
            stack ~= jitCtx.newBinaryOp(JITBinaryOp.DIVIDE, numberType, lhs, rhs);
            break;
        case "mod":
            // Double
            JITRValue rhs = stack.pop;
            JITRValue lhs = stack.pop;
            JITFunction fmod = jitCtx.getBuiltinFunction("fmod");
            stack ~= jitCtx.newCall(fmod, [lhs, rhs]);
            // // Integer
            // JITRValue rhs = stack.pop;
            // JITRValue lhs = stack.pop;
            // stack ~= jitCtx.newBinaryOp(JITBinaryOp.MODULO, numberType, lhs, rhs);
            break;
        case "sub":
            JITRValue rhs = stack.pop;
            JITRValue lhs = stack.pop;
            stack ~= jitCtx.newBinaryOp(JITBinaryOp.MINUS, numberType, lhs, rhs);
            break;
        case "add":
            JITRValue rhs = stack.pop;
            JITRValue lhs = stack.pop;
            stack ~= jitCtx.newBinaryOp(JITBinaryOp.PLUS, numberType, lhs, rhs);
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

    JITRValue printNumFuncPtr()
    {
        JITParam param1 = jitCtx.newParam(numberType, "num");
        JITParam closure = jitCtx.newParam(bytePtr, "closure");
        JITFunction func = jitCtx.newFunction(JITFunctionKind.EXPORTED,
                jitCtx.getType(JITTypeKind.UNSIGNED_CHAR), "_P2ioI5printFZ1N",
                false, [param1, closure,]);
        JITBlock blk = func.newBlock();
        JITType[] printfArgs = [getStringType, numberType];
        JITType printfType = jitCtx.newFunctionType(numberType, false, printfArgs);
        JITFunction funcPrintf = jitCtx.getBuiltinFunction("__builtin_printf");
        JITRValue printfPtr = jitCtx.newCast(funcPrintf.getAddress, printfType);
        JITRValue arg = func.getParam(0);
        JITRValue fmt = jitCtx.newRValue(getStringType, cast(void*) "%lf\n".ptr);
        JITRValue printfPtrCalled = jitCtx.newCall(printfPtr, [fmt, arg]);
        blk.addEval(printfPtrCalled);
        blk.endWithReturn(jitCtx.newRValue(jitCtx.getType(JITTypeKind.UNSIGNED_CHAR), false));
        return func.getAddress;
    }

    JITRValue nullClosure(JITRValue func)
    {
        string closureName = genClosureName;
        JITLValue lval = jitFunc.newLocal(closureType, closureName ~ "_var");
        JITType voidfunc = jitCtx.newFunctionType(bytePtr, false);
        jitBlock.addAssignment(lval.accessField(funcptr), func.castTo(voidfunc));
        jitBlock.addAssignment(lval.accessField(dataptr), jitCtx.nil(bytePtr));
        return lval;
    }

    void emit(CallInstruction call)
    {
        JITRValue[] args = stack[$ - call.argc .. $];
        stack.length -= call.argc;
        // JITRValue closure = stack[$ - 1];
        // stack.length--;
        JITRValue func = stack[$ - 1];
        JITType retty = jitTypeOf(call.doesPush[0]);
        JITRValue callResult = callClosure(retty, func, args);
        stack[$ - 1] = callResult;
    }

    void emit(OperatorInstruction op)
    {
        if (op.op == "index")
        {
            writeln(op.doesPush[0]);
            Type.Options opts = op.doesPush[0];
            Type.Function[] funcs;
            foreach (ty; opts.options)
            {
                writeln(ty);
                if(typeid(ty) != typeid(Type.Function))
                {
                    continue;
                }
                Type.Function func = cast(Type.Function) ty;
                if (!func.exact)
                {
                    continue;
                }
                writeln(func.args.exact);
                writeln(func.retn, " <- ", func.args);
                final switch (func.func)
                {
                case "_print":
                    
                    func.retn = new Type.Options(new Type.Nil);
                    stack ~= nullClosure(printNumFuncPtr);
                    return;
                }
            }
            throw new Exception("cannot index dynamic yet");
        }
        emitOpBinary(op.op);
    }

    // JITRValue addClosureVar(Type type, string name)
    // {
    //     return closure.getVar(name);
    // }

    void emit(LoadInstruction load)
    {
        final switch (load.capture)
        {
        case LoadInstruction.Capture.unk:
            assert(false);
        case LoadInstruction.Capture.arg:
            stack ~= locals[load.var].value;
            break;
        case LoadInstruction.Capture.not:
            stack ~= locals[load.var].value;
            break;
        case LoadInstruction.Capture.cap:
            stack ~= locals[load.var].value;
        }
    }

    void emit(StoreInstruction store)
    {
        jitBlock.addAssignment(locals[store.var].value, stack[$ - 1]);
    }

    void emit(PopInstruction _)
    {
        stack.pop;
    }

    JITType memoString;
    JITType getStringType()
    {
        if (memoString !is null)
        {
            return memoString;
        }
        JITType charType = jitCtx.getType(JITTypeKind.CHAR);
        JITType charPtrType = charType.constOf.pointerOf;
        // JITField charPtrField = jitCtx.newField(charPtrType, "mem");
        // JITType lengthType = jitCtx.getIntType(8, false);
        // JITStruct str = jitCtx.newStructType("string");
        // memoString = str;
        return charPtrType;
    }

    JITRValue newString(string str)
    {
        JITType strType = getStringType;
        JITRValue res = jitCtx.newRValue(strType, cast(void*) str.toStringz);
        return res;
    }

    void emit(PushInstruction push)
    {
        Dynamic val = push.value;
        switch (val.type)
        {
        case Dynamic.Type.nil:
            stack ~= jitCtx.newRValue(jitCtx.getType(JITTypeKind.UNSIGNED_CHAR), false);
            break;
        case Dynamic.Type.log:
            stack ~= jitCtx.newRValue(jitCtx.getType(JITTypeKind.UNSIGNED_CHAR), val.log);
            break;
        case Dynamic.Type.sml:
            // stack ~= jitCtx.newRValue(numberType, val.as!int);
            stack ~= consNumber(val.as!double);
            break;
        case Dynamic.Type.str:
            stack ~= newString(val.str);
            break;
        default:
            assert(false);
        }
    }

    void entry(BasicBlock block, void delegate(JITBlock) cb)
    {
        if (size_t* num = block in disabled)
        {
            if (*num > 0)
            {
                JITFunction myFunc = jitFunc;
                todoBlocks ~= {
                    JITFunction oldJitFunc = jitFunc;
                    jitFunc = myFunc;
                    entry(block, cb);
                    jitFunc = oldJitFunc;
                };
                return;
            }
        }
        JITFunction myFunc = jitFunc;
        todoBlocks ~= {
            JITFunction oldJitFunc = jitFunc;
            jitFunc = myFunc;
            JITBlock arg = emit(block);
            jitFunc = oldJitFunc;
            cb(arg);
        };
    }

    void emit(ReturnBranch retb)
    {
        JITLValue retn = jitFunc.newLocal(stack[$ - 1].getType, genTmpVar);
        jitBlock.addAssignment(retn, stack.pop);
        stack ~= retn;
        if (jitFunc is jitFuncFirst)
        {
            jitBlock.endWithReturn;
        }
        else
        {
            jitBlock.endWithReturn(retn);
        }
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
        if (logb.hasValue)
        {
            JITLValue cond = jitFunc.newLocal(stack[$ - 1].getType, genTmpVar);
            myJitBlock.addAssignment(cond, stack.pop);
            disable(logb.post);
            entry(logb.target[0], (iftrue) {
                entry(logb.target[1], (iffalse) {
                    JITLValue result = jitFunc.newLocal(stack[$ - 1].getType, genTmpVar);
                    JITBlock iftrue2 = jitFunc.newBlock;
                    iftrue2.addAssignment(result, stack.pop);
                    iftrue2.endWithJump(iftrue);
                    JITBlock iffalse2 = jitFunc.newBlock;
                    iffalse2.addAssignment(result, stack.pop);
                    iffalse2.endWithJump(iffalse);
                    myJitBlock.endWithConditional(cond, iftrue2, iffalse2);
                    stack ~= result;
                    enable(logb.post);
                });
            });
        }
        else
        {
            JITRValue cond = stack.pop;
            entry(logb.target[0], (iftrue) {
                entry(logb.target[1], (iffalse) {
                    myJitBlock.endWithConditional(cond, iftrue, iffalse);
                });
            });
        }
    }
}
