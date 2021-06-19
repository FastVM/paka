module purr.ir.walk;

import core.memory;
import std.conv;
import purr.io;
import std.string;
import std.algorithm;
import std.ascii;
import purr.ast.ast;
import purr.srcloc;
import purr.ir.repr;
import purr.ir.opt;
import purr.backend.dlang;
import purr.type.repr;
import purr.type.err;

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
    bool holes;
    Type[string][] localTypes = [];
    Value[string][] localDefs = [];
    Todo[][] todos = [];
    Type[Span] editInfo;

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

    string walkProgram(Node node)
    {
        holes = false;
        localTypes ~= [
            "Text": Type.higher(Type.text),
            "Int": Type.higher(Type.integer),
            "Nil": Type.higher(Type.nil),
            "Float": Type.higher(Type.float_),
        ];
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
        Compiler compiler = new Compiler;
        string src = compiler.compile(globals);
        return src;
        // Bytecode func = Bytecode.empty;
        // BytecodeEmitter emitter = new BytecodeEmitter;
        // if (holes)
        // {
        //     throw new Exception("compilation stopped, ?? hole found");
        // }
        // emitter.emitInFunc(func, start);
        // return func;
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
        Type ret = null;
        switch (node.id)
        {
        case NodeKind.call:
            ret = walkExact(cast(Form) node);
            break;
        case NodeKind.ident:
            ret = walkExact(cast(Ident) node);
            break;
        case NodeKind.value:
            ret = walkExact(cast(Value) node);
            break;
        default:
            assert(false);
        }
        editInfo[node.span] = ret;
        return ret;
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
        else if (ident[0] == '?')
        {
            ident = ident[1..$];
            bool debugging = false;
            if (ident[0] == '?')
            {
                holes = true;
                // ident = ident[1..$];
                debugging = true;
            }
            Type ret = Type.unk();
            localTypes[$-1][ident] = Type.higher(ret);
            PushInstruction push = new PushInstruction(new void[0], ret);
            emit(push);
            ret.then((Known known) {
                if (debugging)
                {
                    writeln("type ", ident, " = ", known);
                }
                push.value = new void[known.size];
                push.res = known;
            });
            return ret;
            // return Type.never;
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
                            emit(new PushInstruction(*cast(void[func.impl.sizeof]*)&func.impl, ty));
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
        void check()
        {
            if (!br1.fits(br2))
            {
                throw new Exception("arms of if of different types");
            }
        }
        br1.then((Known kn){
            if (br2.isUnk)
            {
                br2.getUnk.set(kn);
            }
            check;
        });
        br2.then((Known kn){
            if (br1.isUnk)
            {
                br1.getUnk.set(kn);
            }
            check;
        });
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
        emit(new PushInstruction(false, Type.logical));
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
        emit(new PushInstruction(true, Type.logical));
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
        Node funForm = new Form("lambda", new Form("args", call.args[1..$]), defArgs[1..$]);
        Node setForm = new Form("set", call.args[0], funForm);
        return walk(setForm);
    }

    Type walkLambda(Node[] defArgs)
    {
        Form call = cast(Form) defArgs[0];
        assert(call !is null);
        assert(call.form == "args" || call.form == "call");
        // Unk[] dones;
        // Type[][] checks;
        Type ret = Type.generic(null);

        Generic gen = ret.as!Generic;

        Type specialize(Type[] argTypes)
        {
            outter: foreach (checkno, check; gen.cases)
            {
                if (argTypes.length != check.length)
                {
                    continue;
                }
                inner: foreach (argno, arg; argTypes)
                {
                    if (arg is check[argno])
                    {
                        continue inner;
                    }
                    if (arg.isUnk || check[argno].isUnk)
                    {
                        continue outter;
                    }
                    if (!arg.fits(check[argno]))
                    {
                        continue outter;
                    }
                }
                return gen.rets[checkno];
            }
            Type done = Type.unk;
            if (globals !is null)
            {
                gen.cases ~= argTypes;
                gen.rets ~= done;
            }
            string[] argNames;
            localTypes.length++;
            scope(exit)
            {
                localTypes.length--;
            }
            foreach (i, v; call.args)
            {
                if (Ident name = cast(Ident) v)
                {
                    if (argTypes.length == i)
                    {
                        throw new Exception("too few args");
                    }
                    Type type = argTypes[i];
                    localTypes[$-1][name.repr] = type;
                    argNames ~= name.repr;
                }
            }

            foreach (i, v; call.args)
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
                        Type want = walkType(form.args[1]);
                        Type got = argTypes[i];
                        if (want.isUnk)
                        {
                            want.getUnk.set(got);
                        }
                        if (!want.fits(got))
                        {
                            throw new Exception(
                                    "generic arg got: " ~ got.to!string
                                    ~ ", wanted: " ~ want.to!string);
                        }
                        localTypes[$-1][name.repr] = got;
                        argNames ~= name.repr;
                    }
                }
            }
            BasicBlock lambda = new BasicBlock;
            Func functy = Func.empty;
            functy.args = argTypes;
            if (globals !is null)
            {
                globals.instrs ~= new LambdaInstruction(lambda, argNames, localTypes[$-1], functy.impl);
                todos[$ - 1] ~= Todo(lambda, defArgs, argNames, localTypes[$-1], functy);
            }
            done.getUnk.set(cast(Type) functy);
            return done;
        }

        gen.runme = &specialize;

        return ret;
        // emit(new StoreInstruction(target.repr, ret));
        // localTypes[$ - 1][target.repr] = ret;
        // return ret;
    }

    Type walkStore(Node[] args)
    {
        if (Ident id = cast(Ident) args[0])
        {
            Type ty = walk(args[1]);
            emit(new StoreInstruction(id.repr, ty));
            if (Type *pty = id.repr in localTypes[$ - 1])
            {
                pty.then((Known kn){
                    if (ty.isUnk)
                    {
                        ty.getUnk.set(kn);
                    }
                });
                ty.then((Known kn) {
                    if (pty.isUnk)
                    {
                        pty.getUnk.set(kn);
                    }
                });
            }
            localTypes[$ - 1][id.repr] = ty;
            return Type.nil;
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
                if (args is null || (args.form != "array" && args.form != "join"))
                {
                    throw new Exception("arrow type must take a join as agument representation");
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
                        if (Higher higher = ptr.as!Higher)
                        {
                            return higher.type;
                        }
                    }
                }
                throw new Exception("type not found " ~ id.repr);
            case "Text":
                return Type.text;
            case "Int":
                return Type.integer;
            case "Nil":
                return Type.nil;
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
        ret.then((Known kn) {
            if (curFunc.ret.isUnk)
            {
                curFunc.ret.getUnk.set(kn);
            }
        });
        curFunc.ret.then((Known kn) {
            if (ret.isUnk)
            {
                ret.getUnk.set(curFunc.ret);
            }
        });
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
        Type tr = Type.unk;
        t1.then((Known t1k) {
            if (!t1k.check(Type.integer, Type.float_))
            {
                throw new FailedBinaryOperatorLeft!op(t1k, [Type.integer, Type.float_], t2);
            }
            if (t2.isUnk)
            {
                t2.getUnk.set(t1k);
            }
            if (tr.isUnk)
            {
                tr.getUnk.set(t1k);
            }
        });
        t2.then((Known t2k) {
            if (!t2k.check(Type.integer, Type.float_))
            {
                throw new FailedBinaryOperatorRight!op(t2k, [Type.integer, Type.float_], t1);
            }
            if (t1.isUnk)
            {
                t1.getUnk.set(t2k);
            }
            if (tr.isUnk)
            {
                tr.getUnk.set(t2k);
            }
        });
        tr.then((Known trk){
            if (t1.isUnk)
            {
                t1.getUnk.set(trk);
            }
            if (t2.isUnk)
            {
                t1.getUnk.set(trk);
            }
            if (t1.fits(Type.float_) || t2.fits(Type.float_))
            {
                tr = Type.float_;
            }
            else if (!t1.check(t2))
            {
                throw new FailedBinaryOperatorArms!op(t1, t2);
            }
        });
        emit(new OperatorInstruction(op, tr, [t1, t2]));
        return tr;
    }

    Type walkUnary(string op)(Node[] args)
    {
        Type t1 = walk(args[0]);
        emit(new OperatorInstruction(op, t1, [t1]));
        return t1;
    }

    Type emitInit(Type ret)
    {
        PushInstruction push = new PushInstruction(new void[ret.size], ret);
        // if (Higher higher = ret.as!Higher)
        // {
        //     throw new Exception("init() cannot be applied to a type of a type");
        // }
        return ret;
    }

    Type walkCall(Node fun, Node[] args)
    {
        if (Value strv = cast(Value) fun)
        {
            if (!Type.text.fits(strv.type))
            {
                throw new Exception("cannot call thing of type: " ~ strv.type.to!string);
            }
            string name = fromStringz(*cast(immutable(char)**) strv.value.ptr);
            return walk(new Form("call", new Ident(name), args));
        }
        else
        {
            if (Ident id = cast(Ident) fun)
            {
                switch (id.repr)
                {
                default:
                    break;
                case "type":
                    BasicBlock lastBlock = block;
                    BasicBlock lastGlobals = globals;
                    scope (exit)
                    {
                        block = lastBlock;
                        globals = lastGlobals;
                    }
                    block = new BasicBlock;
                    globals = null;
                    Type ret = walk(args[0]);
                    return Type.higher(ret);
                case "print":
                    walkPrint(args);
                    return Type.nil;
                case "println":
                    walkPrint(args);
                    Type type = walk(new Value("\n"));
                    emit(new PrintInstruction(type)); 
                    return Type.nil;
                case "init":
                    return emitInit(walk(args[0]));
                }
            }
            Type ty = walk(fun);
            Type[] argTypes;
            foreach (_; 0 .. args.length)
            {
                argTypes ~= Type.unk;
            }
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
            if (Generic generic = ty.as!Generic)
            {
                ty = generic.specialize(argTypes);
            }
            emit(new CallInstruction(ty, argTypes));
            return Type.lambda({
                Func func = ty.as!Func;
                assert(func, fun.to!string);
                return func.ret;
            });
        }
    }


    Type walkPrint(Node[] args)
    {
        foreach (arg; args)
        {
            Type type = walk(arg);
            emit(new PrintInstruction(type)); 
        }
        return Type.nil;
    }

    Type walkTuple(Node[] args)
    {
        Type[] types;
        foreach (arg; args)
        {
            types ~= walk(arg);
        }
        return Type.join(types);
    }

    // Type walkStatic(Node[] args)
    // {
    //     BasicBlock lastBlock = block;
    //     BasicBlock lastGlobals = globals;
    //     scope (exit)
    //     {
    //         block = lastBlock;
    //         globals = lastGlobals;
    //     }
    //     block = new BasicBlock;
    //     globals = null;
    //     Type ret = walk(args[0]);
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
        case "tuple":
            return walkTuple(args);
        case "lambda":
            return walkLambda(args);
        case "set":
            return walkStore(args);
        case "fun":
            return walkFun(args);
        case "call":
            return walkCall(args[0], args[1 .. $]);
        case "return":
            throw new Exception("return is broken");
        case "index":
            return walkIndex(args);
        case "::":
            return walk(new Value(walk(args[0]).fits(walkType(args[1]))));
        case "->":
            return Type.higher(walkType(new Form("->", args)));
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
        // case "static":
        //     return walkStatic(args);
        }
    }

    Type walkExact(Form call)
    {
        return walkSpecialForm(call.form, call.args);
    }

    Type walkExact(Value val)
    {
        // if (cast(Exactly) val.type is null)
        // {
        //     val.type = new Exactly(val.type.as!Known, val.value);
        // }
        emit(new PushInstruction(val.value, val.type));
        return val.type;
    }
}
