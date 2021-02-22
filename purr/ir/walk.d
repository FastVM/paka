module purr.ir.walk;

import core.memory;
import std.conv;
import std.stdio;
import std.string;
import std.algorithm;
import std.ascii;
import purr.base;
import purr.ast;
import purr.dynamic;
import purr.srcloc;
import purr.bytecode;
import purr.ir.repr;
import purr.ir.bytecode;

enum string[] specialForms = [
        "@def", "@set", "@opset", "@while", "@array", "@table", "@return",
        "@if", "@fun", "@do", "-", "+", "*", "/", "%", "<", ">", "<=", ">=",
        "==", "!=", "...", "@index", "=>", "@env", "&&", "||", "~",
        "@inspect", "@rcall", "@call"
    ];

class Walker
{
    Span[] nodes = [Span.init];
    BasicBlock block;
    BasicBlock funcblk;

    BasicBlock bbwalk(Node node)
    {
        BasicBlock entry = new BasicBlock;
        block = entry;
        funcblk = block;
        walk(node);
        emitDefault(new ReturnBranch);
        return entry;
    }

    Function walkProgram(Node node, size_t ctx)
    {
        BasicBlock entry = new BasicBlock;
        block = entry;
        funcblk = block;
        walk(node);
        emitDefault(new ReturnBranch);
        Function func = new Function;
        func.parent = ctx.baseFunction;
        func.captured = func.parent.captured;
        foreach (i; ctx.rootBase)
        {
            func.captab.define(i.name);
        }
        BytecodeEmitter emitter = new BytecodeEmitter;
        emitter.entryFunc(entry, func);
        return func;
    }

    void walk(Node node)
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
        case "call":
            walkExact(cast(Call) node);
            break;
        case "string":
            walkExact(cast(String) node);
            break;
        case "ident":
            walkExact(cast(Ident) node);
            break;
        default:
            assert(false);
        }
    }

    bool inspecting = false;

    void emit(Instruction instr)
    {
        if (inspecting)
        {
            Instruction ainstr = new InspectInstruction;
            ainstr.span = nodes[$ - 1];
            block.instrs ~= ainstr;
        }
        instr.span = nodes[$ - 1];
        block.instrs ~= instr;
        if (inspecting)
        {
            Instruction ainstr = new InspectInstruction;
            ainstr.span = nodes[$ - 1];
            block.instrs ~= ainstr;
        }
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

    void walkExact(Ident id)
    {
        string ident = id.repr;
        if (ident == "@nil" || ident == "nil")
        {
            emit(new PushInstruction(Dynamic.nil));
        }
        else if (ident == "true")
        {
            emit(new PushInstruction(true.dynamic));
        }
        else if (ident == "false")
        {
            emit(new PushInstruction(false.dynamic));
        }
        else if (ident == "args")
        {
            emit(new ArgsInstruction);
        }
        else if (ident.length != 0 && ident[0] == '$' && ident[1 .. $].isNumeric)
        {
            emit(new ArgsInstruction);
            emit(new PushInstruction(ident[1 .. $].to!size_t.dynamic));
            emit(new OperatorInstruction("index"));
        }
        else if (ident.isNumeric)
        {
            emit(new PushInstruction(Dynamic.strToNum(ident)));
        }
        else
        {
            emit(new LoadInstruction(ident));
        }
    }

    void walkIf(Node[] args)
    {
        BasicBlock iftrue = new BasicBlock;
        BasicBlock iffalse = new BasicBlock;
        BasicBlock after = new BasicBlock;
        walk(args[0]);
        emit(new LogicalBranch(iftrue, iffalse, after));
        block = iftrue;
        walk(args[1]);
        emitDefault(new GotoBranch(after));
        block = iffalse;
        walk(args[2]);
        emitDefault(new GotoBranch(after));
        block = after;
    }

    void walkWhile(Node[] args)
    {
        BasicBlock cond = new BasicBlock;
        BasicBlock loop = new BasicBlock;
        BasicBlock after = new BasicBlock;
        emit(new PushInstruction(Dynamic.nil));
        emit(new GotoBranch(cond));
        block = loop;
        emit(new PopInstruction);
        walk(args[1]);
        emit(new GotoBranch(cond));
        block = cond;
        walk(args[0]);
        emit(new LogicalBranch(loop, after, after));
        block = after;
    }

    void walkDo(Node[] args)
    {
        if (args.length == 0)
        {
            emit(new PushInstruction(Dynamic.nil));
        }
        else
        {
            if (args.length != 1)
            {
                foreach (arg; args[0 .. $ - 1])
                {
                    walk(arg);
                    emit(new PopInstruction);
                }
            }
            walk(args[$ - 1]);
        }
    }

    void walkStoreDef(Call lhs, Node rhs)
    {
        Node funCall = new Call(new Ident("@fun"), [
                new Call(lhs.args[1 .. $]), rhs
                ]);
        Node setCall = new Call(new Ident("@set"), [lhs.args[0], funCall]);
        walk(setCall);
    }

    void walkStore(Node[] args)
    {
        if (Ident id = cast(Ident) args[0])
        {
            walk(args[1]);
            emit(new StoreInstruction(id.repr));
        }
        else if (Call call = cast(Call) args[0])
        {
            if (Ident id = cast(Ident) call.args[0])
            {
                if (specialForms.canFind(id.repr))
                {
                    assert(id.repr == "@index");
                    walk(call.args[1]);
                    walk(call.args[2]);
                    walk(args[1]);
                    emit(new StoreIndexInstruction);
                }
                else
                {
                    walkStoreDef(call, args[1]);
                }
            }
            else
            {
                walkStoreDef(call, args[1]);
            }
        }
        else
        {
            assert(false);
        }
    }

    void walkOpStore(Node[] args)
    {
        string opname;
        if (Ident id = cast(Ident) args[0])
        {
            opname = id.repr;
            assert(["add", "sub", "mul", "div", "mod", "cat"].canFind(opname));
        }
        else
        {
            assert(false);
        }
        if (Ident id = cast(Ident) args[1])
        {
            walk(args[2]);
            emit(new OperatorStoreInstruction(opname, id.repr));
        }
        else if (Call call = cast(Call) args[1])
        {
            if (Ident id = cast(Ident) call.args[0])
            {
                if (specialForms.canFind(id.repr))
                {
                    assert(id.repr == "@index");
                    walk(call.args[1]);
                    walk(call.args[2]);
                    walk(args[2]);
                    emit(new OperatorStoreIndexInstruction(opname));
                }
                else
                {
                    assert(false);
                }
            }
            else
            {
                assert(false);
            }
        }
        else
        {
            assert(false);
        }
        //     Ident op = cast(Ident) args[0];
        //     if (Ident id = cast(Ident) args[1])
        //     {
        //         if (["add", "sub", "mul", "div", "mod", "cat"].canFind(op.repr))
        //         {
        //             walk(args[2]);
        //             emit(new OperatorStoreInstruction(op.repr, id.repr));
        //         }
        //         else
        //         {
        //             walk(args[1]);
        //             walk(args[2]);
        //             emit(new OperatorInstruction(op.repr));
        //             emit(new OperatorStoreInstruction(id.repr));
        //         }
        //     }
        //     else if (Call call = cast(Call) args[0])
        //     {
        //         if (Ident id = cast(Ident) call.args[0])
        //         {
        //             if (specialForms.canFind(id.repr))
        //             {
        //                 assert(id.repr == "@index");
        //                 walk(call.args[1]);
        //                 walk(call.args[2]);
        //                 walk(args[1]);
        //                 emit(new OperatroStoreIndexInstruction());
        //             }
        //             else
        //             {
        //                 assert(false);
        //             }
        //         }
        //         else
        //         {
        //             assert(false);
        //         }
        //     }
        //     else
        //     {
        //         assert(false);
        //     }
    }

    void walkDef(Node[] args)
    {
        if (args[0].id == "ident")
        {
            Ident ident = cast(Ident) args[0];
            walk(args[1]);
            emit(new StoreInstruction(ident.repr));
        }
        else
        {
            Call callArgs = cast(Call) args[0];
            Node name = callArgs.args[0];
            Call funArgs = new Call(callArgs.args[1 .. $]);
            Call funCall = new Call(new Ident("@fun"), funArgs ~ args[1 .. $]);
            Call newDef = new Call(new Ident("@def"), [name, funCall]);
            walk(newDef);
        }
    }

    void walkFun(Node[] args)
    {
        Call argl = cast(Call) args[0];
        Dynamic[] argNames;
        foreach (i, v; argl.args)
        {
            Ident id = cast(Ident) v;
            argNames ~= id.repr.dynamic;
        }
        BasicBlock lambda = new BasicBlock;
        emit(new LambdaInstruction(lambda, argNames));
        BasicBlock outter = block;
        BasicBlock outterfunc = funcblk;
        block = lambda;
        foreach (i, v; args[1 .. $])
        {
            if (i != 0)
            {
                emit(new PopInstruction);
            }
            walk(v);
        }
        if (block.exit is null)
        {
            if (args.length == 1)
            {
                emit(new PushInstruction(Dynamic.nil));
            }
            emit(new ReturnBranch);
        }
        block = outter;
        funcblk = outterfunc;
    }

    void walkReturn(Node[] args)
    {
        if (args.length == 0)
        {
            emit(new PushInstruction(Dynamic.nil));
            emit(new ReturnBranch);
        }
        else
        {
            walk(args[0]);
            emit(new ReturnBranch);
        }
    }

    void walkBinary(string op)(Node[] args)
    {
        walk(args[0]);
        walk(args[1]);
        emit(new OperatorInstruction(op));
    }

    void walkUnary(string op)(Node[] args)
    {
        walk(args[0]);
        emit(new OperatorInstruction(op));
    }

    void walkIndex(Node[] args)
    {
        walk(args[0]);
        walk(args[1]);
        emit(new OperatorInstruction("index"));
    }

    void walkArray(Node[] args)
    {
        foreach (i; args)
        {
            walk(i);
        }
        emit(new BuildArrayInstruction(args.length));
    }

    void walkTable(Node[] args)
    {
        foreach (i; args)
        {
            walk(i);
        }
        emit(new BuildTableInstruction(args.length / 2));
    }

    void walkAssert(Node[] args)
    {
        inspecting = true;
        scope (exit)
        {
            inspecting = false;
        }
        walk(args[0]);
    }

    void walkCall2(Node fun, Node arg)
    {
        walk(fun);
        walk(arg);
        emit(new CallInstruction(1));
    }

    void walkSpecialCall(string special, Node[] args)
    {
        switch (special)
        {
        default:
            assert(0, "not implemented: " ~ special);
        case "@do":
            walkDo(args);
            break;
        case "@if":
            walkIf(args);
            break;
        case "@while":
            walkWhile(args);
            break;
        case "@set":
            walkStore(args);
            break;
        case "@array":
            walkArray(args);
            break;
        case "@table":
            walkTable(args);
            break;
        case "@opset":
            walkOpStore(args);
            break;
        case "@fun":
            walkFun(args);
            break;
        case "@inspect":
            walkAssert(args);
            break;
        case "@rcall":
            walkCall2(args[1], args[0]);
            break;
        case "@call":
            walkCall2(args[0], args[1]);
            break;
        case "@def":
            walkDef(args);
            break;
        case "@return":
            walkReturn(args);
            break;
        case "@index":
            walkIndex(args);
            break;
        case "~":
            walkBinary!"cat"(args);
            break;
        case "+":
            walkBinary!"add"(args);
            break;
        case "%":
            walkBinary!"mod"(args);
            break;
        case "-":
            if (args.length == 1)
            {
                walkUnary!"neg"(args);
            }
            else
            {
                walkBinary!"sub"(args);
            }
            break;
        case "*":
            walkBinary!"mul"(args);
            break;
        case "/":
            walkBinary!"div"(args);
            break;
        case "<":
            walkBinary!"lt"(args);
            break;
        case ">":
            walkBinary!"gt"(args);
            break;
        case "<=":
            walkBinary!"lte"(args);
            break;
        case ">=":
            walkBinary!"gte"(args);
            break;
        case "!=":
            walkBinary!"neq"(args);
            break;
        case "==":
            walkBinary!"eq"(args);
            break;
        }
    }

    void walkActualCall(Call call)
    {
        foreach (i; call.args)
        {
            walk(i);
        }
        emit(new CallInstruction(call.args.length - 1));
    }

    void walkExact(Call call)
    {
        assert(call.args.length != 0);
        bool special = false;
        if (Ident id = cast(Ident) call.args[0])
        {
            if ((id.repr.length != 0 && id.repr[0] == '@') || specialForms.canFind(id.repr))
            {
                walkSpecialCall(id.repr, call.args[1 .. $]);
                special = true;
            }
        }
        if (!special)
        {
            walkActualCall(call);
        }
    }

    void walkExact(String str)
    {
        emit(new PushInstruction(str.repr.dynamic));
    }
}
