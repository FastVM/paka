module purr.ir.walk;

import core.memory;
import std.conv;
import purr.io;
import std.string;
import std.algorithm;
import std.ascii;
import purr.ast.ast;
import purr.srcloc;
import purr.vm.bytecode;
import purr.ir.repr;
import purr.ir.bytecode;
import purr.ir.opt;
import purr.type.repr;

__gshared bool dumpast = false;

struct Todo
{
    BasicBlock lambda;
    Node[] args;
    string[] argNames;
    Type[string] locals;
    Func functy;
}

final class Walker
{
    Span[] nodes = [Span.init];
    BasicBlock block;
    BasicBlock globals;
    BasicBlock funcblk;
    Func curFunc;
    Type[string][] localTypes = [];
    Value[string][] localDefs = [];
    Todo[][] todos = [];

    BasicBlock walkBasicBlock(Node node)
    {
        if (dumpast)
        {
            writeln(node);
            writeln;
        }
        BasicBlock entry = new BasicBlock;
        block = entry;
        funcblk = block;
        walk(node);
        return entry;
    }

    Bytecode walkProgram(Node node)
    {
        localTypes.length++;
        localDefs.length++;
        todos.length++;
        scope (exit)
        {
            localTypes.length--;
            localDefs.length--;
            todos.length--;
        }
        curFunc = Func.empty;
        if (dumpast)
        {
            writeln(node);
            writeln;
        }
        BasicBlock start = new BasicBlock;
        BasicBlock entry = new BasicBlock;
        globals = start;
        globals.exit = new GotoBranch(entry);
        block = entry;
        funcblk = block;
        Type ret = walk(node);
        if (block.exit is null)
        {
            emit(new PopInstruction(ret));
            emitDefault(new ReturnBranch(Type.nil));
        }
        while (todos[$ - 1].length != 0)
        {
            Todo first = todos[$ - 1][$ - 1];
            todos[$ - 1].length--;
            runTodo(first);
        }
        Bytecode func = Bytecode.empty;
        BytecodeEmitter emitter = new BytecodeEmitter;
        emitter.emitInFunc(func, start);
        return func;
    }

    Type walk(Node node)
    {
        if (node.span != Span.init)
        {
            nodes ~= node.span;
        }
        scope (exit)
        {
            if (node.span != Span.init)
            {
                nodes.length--;
            }
        }
        switch (node.id)
        {
        case NodeKind.call:
            return walkExact(cast(Form) node);
        case NodeKind.ident:
            return walkExact(cast(Ident) node);
        case NodeKind.value:
            return walkExact(cast(Value) node);
        default:
            assert(false);
        }
    }

    bool inspecting = false;

    void emit(Instruction instr)
    {
        instr.span = nodes[$ - 1];
        block.instrs ~= instr;
    }

    void emitDefault(Branch branch)
    {
        if (block.exit is null)
        {
            branch.span = nodes[$ - 1];
            block.exit = branch;
        }
    }

    void emit(Branch branch)
    {
        assert(block.exit is null);
        branch.span = nodes[$ - 1];
        block.exit = branch;
    }

    Type walkExact(Ident id)
    {
        string ident = id.repr;
        if (ident.isNumeric)
        {
            assert(false);
        }
        else
        {
            Type[string] locals = localTypes[$ - 1];
            if (Type* ret = ident in locals)
            {
                Type ty = *ret;
                emit(new LoadInstruction(ident, ty));
                return ty;
            }
            foreach_reverse (Type[string] level; localTypes[0 .. $ - 1])
            {
                if (Type* ret = ident in level)
                {
                    Type ty = *ret;
                    if (!ty.runtime)
                    {
                        return ty;
                    }
                    if (Func func = ty.as!Func)
                    {
                        if (func.impl !is null)
                        {
                            emit(new PushInstruction(func.impl, ty, ty));
                            return ty;
                        }
                    }
                }
            }
            throw new Exception("undefined variable: " ~ ident);
        }
    }

    Type walkIf(Node[] args)
    {
        BasicBlock iftrue = new BasicBlock;
        BasicBlock iffalse = new BasicBlock;
        BasicBlock after = new BasicBlock;
        walk(args[0]);
        emit(new LogicalBranch(iftrue, iffalse));
        block = iftrue;
        Type br1 = walk(args[1]);
        emitDefault(new GotoBranch(after));
        block = iffalse;
        Type br2 = walk(args[2]);
        emitDefault(new GotoBranch(after));
        block = after;
        if (br1.isUnk)
        {
            br1.getUnk.set(br2);
        }
        else if (br2.isUnk)
        {
            br2.getUnk.set(br1);
        }
        if (!br1.fits(br2))
        {
            throw new Exception("arms of if of different types");
        }
        return br1;
    }

    Type walkAnd(Node[] args)
    {
        BasicBlock iftrue = new BasicBlock;
        BasicBlock iffalse = new BasicBlock;
        BasicBlock after = new BasicBlock;
        walk(args[0]);
        emit(new LogicalBranch(iftrue, iffalse));
        block = iftrue;
        walk(args[1]);
        emitDefault(new GotoBranch(after));
        block = iffalse;
        emit(new PushInstruction(false, Type.logical, Type.logical));
        emitDefault(new GotoBranch(after));
        block = after;
        return Type.logical;
    }

    Type walkOr(Node[] args)
    {
        BasicBlock iftrue = new BasicBlock;
        BasicBlock iffalse = new BasicBlock;
        BasicBlock after = new BasicBlock;
        walk(args[0]);
        emit(new LogicalBranch(iftrue, iffalse));
        block = iftrue;
        emit(new PushInstruction(true, Type.logical, Type.logical));
        emitDefault(new GotoBranch(after));
        block = iffalse;
        walk(args[1]);
        emitDefault(new GotoBranch(after));
        block = after;
        return Type.logical;
    }

    Type walkWhile(Node[] args)
    {
        BasicBlock cond = new BasicBlock;
        BasicBlock iftrue = new BasicBlock;
        BasicBlock after = new BasicBlock;
        emitDefault(new GotoBranch(cond));
        block = cond;
        walk(args[0]);
        emitDefault(new LogicalBranch(iftrue, after));
        block = iftrue;
        Type blk = walk(args[1]);
        emit(new PopInstruction(blk));
        emitDefault(new GotoBranch(cond));
        block = after;
        return Type.nil;
    }

    Type walkDo(Node[] args)
    {
        if (args.length == 0)
        {
            return Type.nil;
        }
        else
        {
            foreach (arg; args[0 .. $ - 1])
            {
                Type got = walk(arg);
                emit(new PopInstruction(got));
            }
            return walk(args[$ - 1]);
        }
    }

    Type walkStoreFun(Node lhs, Node[] args, Node rhs)
    {
        Node funForm = new Form("fun", [new Form("args", args), rhs]);
        Node setForm = new Form("set", lhs, funForm);
        return walk(setForm);
    }

    Type walkDef(Node[] defArgs)
    {
        Form call = cast(Form) defArgs[0];
        assert(call !is null);
        assert(call.form == "args" || call.form == "call");
        Ident target = cast(Ident) call.args[0];
        assert(target !is null);
        Unk[] dones;
        Type[][] checks;
        Type specialize(Type[] args)
        {
            outter: foreach (checkno, check; checks)
            {
                if (args.length != check.length)
                {
                    continue;
                }
                inner: foreach (argno, arg; args)
                {
                    if (arg is check[argno])
                    {
                        continue inner;
                    }
                    // if (check[argno].isUnk)
                    // {
                    //     continue inner;
                    // }
                    if (arg.isUnk)
                    {
                        // writeln(check[argno], arg);
                        // if (check[argno].isUnk)
                        // {
                        //     continue inner;
                        // }
                        continue outter;
                    }
                    if (!arg.fits(check[argno]))
                    {
                        continue outter;
                    }
                }
                return dones[checkno];
            }
            Unk done = Type.unk.getUnk;
            checks ~= args;
            dones ~= done;
            Type[string] locals;
            string[] argNames;
            Type[] argTypes;
            foreach (i, v; call.args[1 .. $])
            {
                if (Form form = cast(Form) v)
                {
                    if (form.form != "::")
                    {
                        throw new Exception("args type must start with a `::`");
                    }
                    else
                    {
                        Ident name = cast(Ident) form.args[0];
                        Type type = walkType(form.args[1]);
                        locals[name.repr] = type;
                        argNames ~= name.repr;
                        argTypes ~= type;
                    }
                }
                if (Ident name = cast(Ident) v)
                {
                    Type type = args[i];
                    locals[name.repr] = type;
                    argNames ~= name.repr;
                    argTypes ~= type;
                }
            }
            BasicBlock lambda = new BasicBlock;
            Func functy = Func.empty;
            functy.args = args;
            // globals.instrs ~= new LambdaInstruction(lambda, argNames, locals, functy.impl);
            block.instrs ~= new LambdaInstruction(lambda, argNames, locals, functy.impl);
            // globals.instrs ~= new PopInstruction(functy);
            todos[$ - 1] ~= Todo(lambda, defArgs, argNames, locals, functy);
            done.set(cast(Type) functy);
            return done;
        }

        Type ret = Type.generic(&specialize);
        // emit(new StoreInstruction(target.repr, ret));
        localTypes[$ - 1][target.repr] = ret;
        return ret;
    }

    Type walkStore(Node[] args)
    {
        if (Ident id = cast(Ident) args[0])
        {
            Type ty = walk(args[1]);
            emit(new StoreInstruction(id.repr, ty));
            localTypes[$ - 1][id.repr] = ty;
            return ty;
        }
        else if (Form call = cast(Form) args[0])
        {
            if (call.form == "args" || call.form == "call")
            {
                return walkStoreFun(call.args[0], call.args[1 .. $], args[1]);
            }
            else
            {
                assert(false, call.form);
            }
        }
        else
        {
            assert(false);
        }
    }

    Type walkType(Node node)
    {
        switch (node.id)
        {
        case NodeKind.call:
            Form form = cast(Form) node;
            switch (form.form)
            {
            default:
                throw new Exception("not allowed in a type: " ~ form.form);
            case "->":
                Func func = Type.func(null).as!Func;
                func.ret = walkType(form.args[1]);
                Form args = cast(Form) form.args[0];
                if (args is null || args.form != "array")
                {
                    throw new Exception("arrow type must take an array as agument representation");
                }
                foreach (arg; args.args)
                {
                    func.args ~= walkType(arg);
                }
                return func;
            }
            assert(false);
        case NodeKind.ident:
            Ident id = cast(Ident) node;
            switch (id.repr)
            {
            default:
                foreach (layer; localTypes)
                {
                    if (Type* ptr = id.repr in layer)
                    {
                        return *ptr;
                    }
                }
                throw new Exception("type not found " ~ id.repr);
            case "Frame":
                return Type.frame;
            case "Text":
                return Type.text;
            case "Integer":
                return Type.integer;
            case "Float":
                return Type.float_;
            }
            break;
        case NodeKind.value:
            throw new Exception("type cannot be a literal value");
        default:
            assert(false);
        }
    }

    void runTodo(Todo todo)
    {
        BasicBlock last = block;
        todos.length++;
        localTypes ~= todo.locals;
        curFunc = todo.functy;
        scope (exit)
        {
            block = last;
            todos.length--;
            localTypes.length--;
        }
        block = todo.lambda;
        Type ret = Type.nil;
        foreach (i, v; todo.args[1 .. $])
        {
            ret = walk(v);
        }
        if (block.exit is null)
        {
            emitReturn(ret);
        }
        while (todos[$ - 1].length != 0)
        {
            Todo first = todos[$ - 1][$ - 1];
            todos[$ - 1].length--;
            runTodo(first);
        }
    }

    Type walkFun(Node[] args)
    {
        Form argl = cast(Form) args[0];
        Type[string] locals;
        string[] argNames;
        Type[] argTypes;
        foreach (i, v; argl.args)
        {
            if (Form form = cast(Form) v)
            {
                if (form.form != "::")
                {
                    throw new Exception("args type must start with a `::`");
                }
                else
                {
                    Ident name = cast(Ident) form.args[0];
                    Type type = walkType(form.args[1]);
                    locals[name.repr] = type;
                    argNames ~= name.repr;
                    argTypes ~= type;
                }
            }
            if (Ident name = cast(Ident) v)
            {
                Type type = Type.unk;
                locals[name.repr] = type;
                argNames ~= name.repr;
                argTypes ~= type;
            }
        }
        BasicBlock lambda = new BasicBlock;
        Func functy = Func.empty;
        functy.args = argTypes;
        // functy.ret = Type.nil;
        emit(new LambdaInstruction(lambda, argNames, locals, functy.impl));
        todos[$ - 1] ~= Todo(lambda, args, argNames, locals, functy);
        return cast(Type) functy;
    }

    void emitReturn(Type ret)
    {
        if (curFunc.ret.isUnk)
        {
            curFunc.ret.getUnk.set(ret);
        }
        else if (ret.isUnk)
        {
            ret.getUnk.set(curFunc.ret);
        }
        else
        {
            assert(curFunc.ret.fits(ret), curFunc.ret.to!string ~ " vs " ~ ret.to!string);
        }
        emit(new ReturnBranch(ret));
    }

    Type walkReturn(Node[] args)
    {
        if (args.length == 0)
        {
            assert(false);
        }
        Type ret = walk(args[0]);
        return Type.never;
    }

    alias walkIndex = walkBinary!"index";

    Type walkBinary(string op)(Node[] args)
    {
        Type t1 = walk(args[0]);
        Type t2 = walk(args[1]);
        emit(new OperatorInstruction(op, t1, [t1, t2]));
        return t1;
    }

    Type walkUnary(string op)(Node[] args)
    {
        Type t1 = walk(args[0]);
        emit(new OperatorInstruction(op, t1, [t1]));
        return t1;
    }

    Type walkCall(Node fun, Node[] args)
    {
        Type ty = walk(fun);
        Type[] argTypes;
        foreach (_; 0 .. args.length)
        {
            argTypes ~= Type.unk;
        }
        if (Generic generic = ty.as!Generic)
        {
            ty = generic.specialize(argTypes);
        }
        // if (n != 0)
        // {
            // emit(new PushInstruction(ty.as!Func.impl, ty));
        // }
        foreach (argno, arg; args)
        {
            Type argty = walk(arg);
            if (argTypes[argno].isUnk)
            {
                argTypes[argno].getUnk.set(argty);
            }
            else
            {
                throw new Exception("type error in function arguments");
            }
        }
        emit(new CallInstruction(ty, argTypes));
        return Type.lambda({
            Func func = ty.as!Func;
            return func.ret;
        });
    }

    // Type walkRec(Node[] args)
    // {
    //     int size;
    //     foreach (arg; args)
    //     {
    //         Type argty = walk(arg);
    //         size += argty.size;
    //     }
    //     emit(new RecInstruction(size));
    //     return curFunc.ret;
    // }

    Type walkPrint(Node[] args)
    {
        assert(args.length == 1);
        Type type = walk(args[0]);
        emit(new PrintInstruction(type));
        return Type.nil;
    }

    Type walkInfo(Node[] args)
    {
        Ident name = cast(Ident) args[0];
        assert(name !is null);
        switch (name.repr)
        {
        default:
            assert(false, "type info not implemented: " ~ name.repr);
        case "type":
            BasicBlock lastBlock = block;
            scope (exit)
            {
                block = lastBlock;
            }
            block = new BasicBlock;
            Type ret = walk(args[1]);
            return Type.higher(ret);
        }
    }

    // Type walkLabel(Node[] args)
    // {
    //     BasicBlock after = new BasicBlock;
    //     emitDefault(new LabelBranch(after));
    //     block = after;
    //     return Type.frame;
    // }

    // Type walkJump(Node[] args)
    // {
    //     walk(args[0]);
    //     BasicBlock after = new BasicBlock;
    //     emitDefault(new JumpBranch);
    //     block = after;
    //     return Type.nil;
    // }

    Type walkSpecialForm(string special, Node[] args)
    {
        switch (special)
        {
        default:
            assert(0, "not implemented: " ~ special);
        case "do":
            return walkDo(args);
        case "if":
            return walkIf(args);
        case "while":
            return walkWhile(args);
        case "&&":
            return walkAnd(args);
        case "||":
            return walkOr(args);
        case "def":
            return walkDef(args);
        case "set":
            return walkStore(args);
        case "fun":
            return walkFun(args);
        case "rcall":
            return walkCall(args[$ - 1], args[0 .. $ - 1]);
        // case "rec":
        //     return walkRec(args);
        case "info":
            return walkInfo(args);
        case "print":
            return walkPrint(args);
        case "call":
            return walkCall(args[0], args[1 .. $]);
        case "return":
            throw new Exception("return is broken");
            // return walkReturn(args);
        case "index":
            return walkIndex(args);
        case "+":
            return walkBinary!"add"(args);
        case "%":
            return walkBinary!"mod"(args);
        case "not":
            return walkUnary!"not"(args);
        case "-":
            if (args.length == 1)
            {
                return walkUnary!"neg"(args);
            }
            else
            {
                return walkBinary!"sub"(args);
            }
        case "*":
            return walkBinary!"mul"(args);
        case "/":
            return walkBinary!"div"(args);
        case "<":
            return walkBinary!"lt"(args);
        case ">":
            return walkBinary!"gt"(args);
        case "<=":
            return walkBinary!"lte"(args);
        case ">=":
            return walkBinary!"gte"(args);
        case "!=":
            return walkBinary!"neq"(args);
        case "==":
            return walkBinary!"eq"(args);
        }
    }

    Type walkExact(Form call)
    {
        return walkSpecialForm(call.form, call.args);
    }

    Type walkExact(Value val)
    {
        emit(new PushInstruction(val.value, val.type, val.type));
        return val.type;
    }
}
