module purr.ir.walk;

import core.memory;
import std.conv;
import purr.io;
import std.string;
import std.algorithm;
import std.ascii;
import purr.base;
import purr.ast.ast;
import purr.dynamic;
import purr.srcloc;
import purr.bytecode;
import purr.ir.repr;
import purr.ir.bytecode;
import purr.ir.opt;

__gshared bool dumpast = false;

final class Walker
{
    Span[] nodes = [Span.init];
    BasicBlock block;
    BasicBlock funcblk;

    BasicBlock walkBasicBlock(Node node, size_t ctx)
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

    Bytecode walkProgram(Node node, size_t ctx)
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
        if (block.exit is null)
        {
            emitDefault(new ReturnBranch);
        }
        Bytecode func = new Bytecode;
        func.parent = ctx.baseFunction;
        func.captured = func.parent.captured;
        foreach (i; ctx.rootBase)
        {
            func.captab.define(i.name);
        }
        Opt opt = new Opt;
        opt.opt(entry);
        BytecodeEmitter emitter = new BytecodeEmitter;
        emitter.emitInFunc(func, entry);
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
        case NodeKind.call:
            walkExact(cast(Form) node);
            break;
        case NodeKind.ident:
            walkExact(cast(Ident) node);
            break;
        case NodeKind.value:
            walkExact(cast(Value) node);
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
        if (ident == "rec")
        {
            emit(new RecInstruction);
        }
        else if (ident.length != 0 && ident[0] == '$' && ident[1 .. $].isNumeric)
        {
            emit(new ArgNumberInstruction(ident[1 .. $].to!size_t));
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
        emit(new LogicalBranch(iftrue, iffalse));
        block = iftrue;
        walk(args[1]);
        emitDefault(new GotoBranch(after));
        block = iffalse;
        walk(args[2]);
        emitDefault(new GotoBranch(after));
        block = after;
    }

    void walkAnd(Node[] args)
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
        emit(new PushInstruction(false.dynamic));
        emitDefault(new GotoBranch(after));
        block = after;
    }

    void walkOr(Node[] args)
    {
        BasicBlock iftrue = new BasicBlock;
        BasicBlock iffalse = new BasicBlock;
        BasicBlock after = new BasicBlock;
        walk(args[0]);
        emit(new LogicalBranch(iftrue, iffalse));
        block = iftrue;
        emit(new PushInstruction(true.dynamic));
        emitDefault(new GotoBranch(after));
        block = iffalse;
        walk(args[1]);
        emitDefault(new GotoBranch(after));
        block = after;
    }

    void walkWhile(Node[] args)
    {
        BasicBlock cond = new BasicBlock;
        BasicBlock loop = new BasicBlock;
        BasicBlock after1 = new BasicBlock;
        emit(new GotoBranch(cond));
        block = loop;
        walk(args[1]);
        emit(new GotoBranch(cond));
        emit(new PopInstruction);
        block = cond;
        walk(args[0]);
        emit(new LogicalBranch(loop, after1));
        block = after1;
        emit(new PushInstruction(Dynamic.nil));
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

    void walkStoreDef(Node lhs, Node[] args, Node rhs)
    {
        Node funForm = new Form("fun", [
                new Form("args", args), rhs
                ]);
        Node setForm = new Form("set", lhs, funForm);
        walk(setForm);
    }
    
    void walkStoreIndex(Node on, Node ind, Node val)
    {
        walk(on);
        walk(ind);
        walk(val);
        emit(new StoreIndexInstruction);
    }

    void walkStore(Node[] args)
    {
        if (Ident id = cast(Ident) args[0])
        {
            walk(args[1]);
            emit(new StoreInstruction(id.repr));
        }
        else if (Form call = cast(Form) args[0])
        {
            if (call.form == "call")
            {
                walkStoreDef(call.args[0], call.args[1..$], args[1]);
            }
            else if (call.form == "args")
            {
                walkStoreDef(call.args[0], call.args[1..$], args[1]);
            }
            else if (call.form == "index")
            {
                walkStoreIndex(call.args[0], call.args[1], args[1]);
            }
            else if (call.form == "cache")
            {
                walkStore([call.args[0], args[1]]);
            }
            else if (call.form == "do")
            {
                walkDo(call.args[0..$-1]);
                emit(new PopInstruction);
                walkStore([call.args[$-1], args[1]]);
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

    void walkFun(Node[] args)
    {
        Form argl = cast(Form) args[0];
        string[] argNames;
        foreach (i, v; argl.args)
        {
            Ident id = cast(Ident) v;
            assert(id, v.to!string);
            argNames ~= id.repr;
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
            if (args.length == 0)
            {
                emitDefault(new ConstReturnBranch(Dynamic.nil));
            }
            else
            {
                emitDefault(new ReturnBranch);
            }
        }
        block = outter;
        funcblk = outterfunc;
    }

    void walkReturn(Node[] args)
    {
        if (args.length == 0)
        {
            // emit(new ConstReturnBranch(Dynamic.nil));
            assert(false);
        }
        walk(args[0]);
        emit(new ReturnBranch);
    }

    alias walkIndex = walkBinary!"index";

    void walkBinary(string op)(Node[] args)
    {
        walk(args[0]);
        if (Value val = cast(Value) args[1])
        {
            emit(new ConstOperatorInstruction(op, val.value));
        }
        else
        {
            walk(args[1]);
            emit(new OperatorInstruction(op));
        }
    }

    void walkUnary(string op)(Node[] args)
    {
        walk(args[0]);
        emit(new OperatorInstruction(op));
    }

    void walkConst(Node[] args)
    {
        BasicBlock oper = new BasicBlock;
        BasicBlock after = new BasicBlock;
        foreach (check; args[1..$])
        {
            walk(check);
        }
        emitDefault(new ConstBranch(oper, after, args.length - 1));
        block = oper;
        walk(args[0]);
        emitDefault(new GotoBranch());
        block = after;
    }

    // void walkConst(Node[] args)
    // {
    //     walk(args[0]);
    // }

    void walkTuple(Node[] args)
    {
        foreach (i; args)
        {
            walk(i);
        }
        emit(new BuildTupleInstruction(args.length));
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

    void walkForm(Node fun, Node[] args)
    {
        walk(fun);
        foreach (arg; args) {
            walk(arg);
        }
        emit(new CallInstruction(args.length));
    }

    void walkSpecialForm(string special, Node[] args)
    {
        switch (special)
        {
        default:
            assert(0, "not implemented: " ~ special);
        case "do":
            walkDo(args);
            break;
        case "if":
            walkIf(args);
            break;
        case "while":
            walkWhile(args);
            break;
        case "&&":
            walkAnd(args);
            break;
        case "||":
            walkOr(args);
            break;
        case "set":
            walkStore(args);
            break;
        case "tuple":
            walkTuple(args);
            break;
        case "array":
            walkArray(args);
            break;
        case "table":
            walkTable(args);
            break;
        case "fun":
            walkFun(args);
            break;
        case "inspect":
            walkAssert(args);
            break;
        case "rcall":
            walkForm(args[$-1], args[0..$-1]);
            break;
        case "call":
            walkForm(args[0], args[1..$]);
            break;
        case "return":
            walkReturn(args);
            break;
        case "index":
            walkIndex(args);
            break;
        case "cache":
            walkConst(args);
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

    void walkExact(Form call)
    {
        walkSpecialForm(call.form, call.args);
    }

    void walkExact(Value val)
    {
        emit(new PushInstruction(val.value.dynamic));
    }
}
