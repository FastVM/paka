module lang.walk;

import lang.ast;
import lang.base;
import lang.bytecode;
import lang.dynamic;
import lang.ssize;
import lang.number;
import std.algorithm;
import std.conv;
import std.string;
import std.stdio;

enum string[] specialForms = [
        "@def", "@set", "@opset", "@while", "@array", "@table", "@target",
        "@return", "@if", "@fun", "@do", "@using", "F+", "-", "+", "*", "/",
        "@dotmap-both", "@dotmap-lhs", "@dotmap-rhs", "@dotmap-pre", "%",
        "<", ">", "<=", ">=", "==", "!=", "...", "@index", "=>"
    ];

bool isUnpacking(Node[] args)
{
    foreach (i; args)
    {
        Call call = cast(Call) i;
        if (call is null)
        {
            continue;
        }
        Ident id = cast(Ident) call.args[0];
        if (id is null)
        {
            continue;
        }
        if (id.repr == "...")
        {
            return true;
        }
    }
    return false;
}

class Walker
{
    Function func;
    int[2] stackSize;
    bool isTarget = false;
    Node[] nodes;

    Function walkProgram(bool ctfe = false)(Node node, size_t ctx)
    {
        static if (ctfe)
        {
            func = new Function;
            func.parent = baseCtfeFunction;
            foreach (i; rootCtfeBase)
            {
                func.captab.define(i.name);
            }
        }
        else
        {
            func = new Function;
            func.parent = ctx.baseFunction;
            foreach (i; ctx.rootBase)
            {
                func.captab.define(i.name);
            }
        }
        walk(node);
        pushInstr(func, Instr(Opcode.retval));
        func.stackSize =  stackSize[1];
        func.resizeStack;
        return func;
    }

    void pushInstr(Function func, Instr instr, int size = 0)
    {
        func.instrs ~= instr;
        int* psize = instr.op in opSizes;
        if (psize !is null)
        {
            stackSize[0] += *psize;
        }
        else
        {
            stackSize[0] = size;
        }
        checkStack;
    }

    void checkStack()
    {
        if (stackSize[0] > stackSize[1])
        {
            stackSize[1] = stackSize[0];
        }
    }

    bool isSpecialCall(Node node)
    {
        if (node.id != "ident")
        {
            return false;
        }
        Ident ident = cast(Ident) node;
        if (!specialForms.canFind(ident.repr))
        {
            return false;
        }
        return true;
    }

    void doPop()
    {
        pushInstr(func, Instr(Opcode.pop));
    }

    void walk(Node node)
    {
        nodes ~= node;
        scope(exit) {
            nodes.length--;
        }
        // writeln(node.span.pretty, " -> ", node);
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
            assert(0);
        }
    }

    void walkDef(Node[] args)
    {
        if (args[0].id == "ident")
        {
            Ident ident = cast(Ident) args[0];
            uint place = func.stab.define(ident.repr);
            walk(args[1]);
            pushInstr(func, Instr(Opcode.store, place));
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

    void walkDo(Node[] args)
    {
        if (args.length == 0)
        {
            pushInstr(func, Instr(Opcode.push, cast(uint) func.constants.length));

            func.constants ~= Dynamic.nil;
        }
        foreach (i, v; args)
        {
            if (i != 0)
            {
                doPop;

            }
            walk(v);
        }
    }

    void walkIf(Node[] args)
    {
        walk(args[0]);
        size_t ifloc = func.instrs.length;
        pushInstr(func, Instr(Opcode.iffalse));

        walk(args[1]);
        func.instrs[ifloc].value = cast(uint) func.instrs.length;
        size_t jumploc = func.instrs.length;
        pushInstr(func, Instr(Opcode.jump));
        walk(args[2]);
        func.instrs[jumploc].value = cast(uint)(func.instrs.length - 1);
    }

    void walkWhile(Node[] args)
    {
        size_t redo = func.instrs.length - 1;
        walk(args[0]);
        size_t whileloc = func.instrs.length;
        pushInstr(func, Instr(Opcode.iffalse));

        walk(args[1]);
        doPop;

        pushInstr(func, Instr(Opcode.jump, cast(uint) redo));
        func.instrs[whileloc].value = cast(uint)(func.instrs.length - 1);
        pushInstr(func, Instr(Opcode.push, cast(uint) func.constants.length));

        func.constants ~= Dynamic.nil;
    }

    void walkArrowFun(Node[] args)
    {
        Ident argid = cast(Ident) args[0];
        if (argid is null)
        {
            walkFun(args);
        }
        else
        {
            Function last = func;
            int[2] stackOld = stackSize;
            stackSize = [0, 0];
            Function newFunc = new Function;
            func.flags |= Function.Flags.isLocal;
            func = newFunc;
            func.parent = last;
            newFunc.stab.set(argid.repr, cast(uint) 0);
            walk(args[1]);
            pushInstr(func, Instr(Opcode.retval));
            newFunc.stackSize = stackSize[1];
            stackSize = stackOld;
            func = last;
            pushInstr(func, Instr(Opcode.sub, cast(uint) func.funcs.length));

            last.funcs ~= newFunc;
            newFunc.resizeStack;
        }
    }

    void walkFun(Node[] args)
    {
        Call argl = cast(Call) args[0];
        Function lastFunc = func;
        int[2] stackOld = stackSize;
        stackSize = [0, 0];
        Function newFunc = new Function;
        func.flags |= Function.Flags.isLocal;
        func = newFunc;
        func.parent = lastFunc;
        foreach (i, v; argl.args)
        {
            Ident id = cast(Ident) v;
            func.stab.set(id.repr, cast(uint) i);
        }
        foreach (i, v; args[1 .. $])
        {
            if (i != 0)
            {
                pushInstr(func, Instr(Opcode.pop));

            }
            walk(v);
        }
        pushInstr(func, Instr(Opcode.retval));
        func.stackSize = stackSize[1];
        func.resizeStack;
        stackSize = stackOld;
        func = lastFunc;
        pushInstr(func, Instr(Opcode.sub, cast(uint) func.funcs.length));

        func.funcs ~= newFunc;
    }

    void walkBinary(string op)(Node[] args)
    {
        walk(args[0]);
        walk(args[1]);
        pushInstr(func, Instr(mixin("Opcode.op" ~ op)));
    }

    void walkUnary(string op)(Node[] args)
    {
        walk(args[0]);
        pushInstr(func, Instr(mixin("Opcode.op" ~ op)));
    }

    void walkSet(Node[] c)
    {
        foreach (p; 0 .. c.length / 2)
        {
            walk(c[p * 2 + 1]);
        }
        foreach_reverse (p; 0 .. c.length / 2)
        {
            Node target = c[p * 2];
            if (cast(Call) target)
            {
                Call call = cast(Call) target;
                Ident ident = cast(Ident) call.args[0];
                string name = ident.repr;
                switch (name)
                {
                case "@index":
                    walk(call.args[1]);
                    walk(call.args[2]);
                    pushInstr(func, Instr(Opcode.istore));

                    break;
                case "@table":
                case "@array":
                    walk(new Call(new Ident("@target"), [call]));
                    pushInstr(func, Instr(Opcode.tstore));

                    break;
                default:
                    assert(0);
                }
            }
            else if (Ident ident = cast(Ident) target)
            {
                uint* us = ident.repr in func.stab.byName;
                if (us is null)
                {
                    uint place = func.stab.define(ident.repr);
                    pushInstr(func, Instr(Opcode.store, place));
                }
                else
                {
                    pushInstr(func, Instr(Opcode.store, *us));
                }
            }
            else
            {
                assert(0);
            }
        }
    }

    void walkOpSet(Node[] c)
    {
        Ident id = cast(Ident) c[0];
        c = c[1 .. $];
        foreach (p; 0 .. c.length / 2)
        {
            walk(c[p * 2 + 1]);
        }
        foreach_reverse (p; 0 .. c.length / 2)
        {
            Node target = c[p * 2];
            if (cast(Call) target)
            {
                Call call = cast(Call) target;
                Ident ident = cast(Ident) call.args[0];
                string name = ident.repr;
                switch (name)
                {
                case "@index":
                    walk(call.args[1]);
                    walk(call.args[2]);
                    pushInstr(func, Instr(Opcode.opistore, id.repr.to!AssignOp));

                    break;
                case "@table":
                case "@array":
                    walk(new Call(new Ident("@target"), [call]));
                    pushInstr(func, Instr(Opcode.optstore, id.repr.to!AssignOp));

                    break;
                default:
                    assert(0);
                }
            }
            else
            {
                Ident ident = cast(Ident) target;
                uint* us = ident.repr in func.stab.byName;
                if (us is null)
                {
                    uint place = func.stab.define(ident.repr);
                    pushInstr(func, Instr(Opcode.opstore, place));
                }
                else
                {
                    pushInstr(func, Instr(Opcode.opstore, *us));
                }
                pushInstr(func, Instr(Opcode.push, id.repr.to!AssignOp));
                func.constants ~= dynamic(Dynamic.Type.nil);
            }
        }
    }

    void walkReturn(Node[] args)
    {
        if (args.length == 0)
        {
            pushInstr(func, Instr(Opcode.retnone));
        }
        else
        {
            walk(args[0]);
            pushInstr(func, Instr(Opcode.retval));
            doPop;

        }
    }

    void walkArray(Node[] args)
    {
        uint tmp = stackSize[0];
        pushInstr(func, Instr(Opcode.push, cast(uint) func.constants.length));
        func.constants ~= dynamic(Dynamic.Type.end);
        int used = stackSize[0];
        foreach (i; args)
        {
            walk(i);
        }
        if (isTarget)
        {
            pushInstr(func, Instr(Opcode.targeta), used);
        }
        else
        {
            pushInstr(func, Instr(Opcode.array), used);
        }
        stackSize[0] = tmp + 1;

    }

    void walkTable(Node[] args)
    {
        uint tmp = stackSize[0];
        pushInstr(func, Instr(Opcode.push, cast(uint) func.constants.length));
        func.constants ~= dynamic(Dynamic.Type.end);
        uint used = stackSize[0];
        foreach (i; args)
        {
            walk(i);
        }
        pushInstr(func, Instr(Opcode.table, cast(uint) args.length), stackSize[0] - used);
        stackSize[0] = tmp + 1;

    }

    void walkTarget(Node[] args)
    {
        bool lastTarget = isTarget;
        scope (exit)
        {
            isTarget = lastTarget;
        }
        isTarget = true;
        walk(args[0]);
    }

    void walkIndex(Node[] args)
    {
        if (isTarget)
        {
            isTarget = false;
            pushInstr(func, Instr(Opcode.push, cast(uint) func.constants.length));
            uint used = stackSize[0];
            func.constants ~= dynamic(Dynamic.Type.end);
            walk(args[0]);
            walk(args[1]);
            isTarget = true;
            pushInstr(func, Instr(Opcode.targeta), stackSize[0] - used);
            pushInstr(func, Instr(Opcode.data));
        }
        else
        {
            walk(args[0]);
            walk(args[1]);
            pushInstr(func, Instr(Opcode.index));

        }
    }

    void walkUnpack(Node[] args)
    {
        pushInstr(func, Instr(Opcode.unpack));
        walk(args[0]);
    }

    void walkDotmap(string s)(Node[] args)
    {
        static if (s == "_pre_map")
        {
            Node[] xy = [new Ident("_rhs")];
            Node lambdaBody = new Call([args[0]] ~ xy);
            Call lambda = new Call(new Ident("@fun"), [new Call(xy), lambdaBody]);
            Call domap = new Call(new Ident(s), [cast(Node) lambda] ~ args[1 .. $]);
            walk(domap);
        }
        else
        {
            Node[] xy = [new Ident("_lhs"), new Ident("_rhs")];
            Node lambdaBody = new Call(args[0 .. $ - 2] ~ xy);
            Call lambda = new Call(new Ident("@fun"), [new Call(xy), lambdaBody]);
            Call domap = new Call(new Ident(s), [cast(Node) lambda] ~ args[$ - 2 .. $]);
            walk(domap);
        }
    }

    void walkSpecialCall(Call c)
    {
        final switch ((cast(Ident) c.args[0]).repr)
        {
        case "@def":
            walkDef(c.args[1 .. $]);
            break;
        case "@fun":
            walkFun(c.args[1 .. $]);
            break;
        case "=>":
            walkArrowFun(c.args[1 .. $]);
            break;
        case "@set":
            walkSet(c.args[1 .. $]);
            break;
        case "@opset":
            walkOpSet(c.args[1 .. $]);
            break;
        case "@do":
            walkDo(c.args[1 .. $]);
            break;
        case "@if":
            walkIf(c.args[1 .. $]);
            break;
        case "@while":
            walkWhile(c.args[1 .. $]);
            break;
        case "@return":
            walkReturn(c.args[1 .. $]);
            break;
        case "@array":
            walkArray(c.args[1 .. $]);
            break;
        case "@table":
            walkTable(c.args[1 .. $]);
            break;
        case "@index":
            walkIndex(c.args[1 .. $]);
            break;
        case "@target":
            walkTarget(c.args[1 .. $]);
            break;
        case "@dotmap-both":
            walkDotmap!"_both_map"(c.args[1 .. $]);
            break;
        case "@dotmap-lhs":
            walkDotmap!"_lhs_map"(c.args[1 .. $]);
            break;
        case "@dotmap-rhs":
            walkDotmap!"_rhs_map"(c.args[1 .. $]);
            break;
        case "@dotmap-pre":
            walkDotmap!"_pre_map"(c.args[1 .. $]);
            break;
        case "+":
            walkBinary!"add"(c.args[1 .. $]);
            break;
        case "%":
            walkBinary!"mod"(c.args[1 .. $]);
            break;
        case "-":
            if (c.args.length == 2)
            {
                walkUnary!"neg"(c.args[1 .. $]);
            }
            else
            {
                walkBinary!"sub"(c.args[1 .. $]);
            }
            break;
        case "*":
            walkBinary!"mul"(c.args[1 .. $]);
            break;
        case "/":
            walkBinary!"div"(c.args[1 .. $]);
            break;
        case "<":
            walkBinary!"lt"(c.args[1 .. $]);
            break;
        case ">":
            walkBinary!"gt"(c.args[1 .. $]);
            break;
        case "<=":
            walkBinary!"lte"(c.args[1 .. $]);
            break;
        case ">=":
            walkBinary!"gte"(c.args[1 .. $]);
            break;
        case "!=":
            walkBinary!"neq"(c.args[1 .. $]);
            break;
        case "==":
            walkBinary!"eq"(c.args[1 .. $]);
            break;
        case "...":
            walkUnpack(c.args[1 .. $]);
            break;
        }
    }

    void walkExact(Call c)
    {
        if (isSpecialCall(c.args[0]))
        {
            walkSpecialCall(c);
        }
        else
        {
            if (isUnpacking(c.args[1 .. $]))
            {
                walk(c.args[0]);
                uint used = stackSize[0];
                pushInstr(func, Instr(Opcode.push, cast(uint) func.constants.length));

                func.constants ~= dynamic(Dynamic.Type.end);
                foreach (i; c.args[1 .. $])
                {
                    walk(i);
                }
                pushInstr(func, Instr(Opcode.upcall, cast(uint)(c.args.length - 1)), used);

            }
            else
            {
                walk(c.args[0]);
                uint used = stackSize[0];
                foreach (i; c.args[1 .. $])
                {
                    walk(i);
                }
                pushInstr(func, Instr(Opcode.call, cast(uint)(c.args.length - 1)), used);

            }
        }
    }

    void walkExact(String s)
    {
        pushInstr(func, Instr(Opcode.push, cast(uint) func.constants.length));

        func.constants ~= dynamic(s.repr);
    }

    void walkExact(Ident i)
    {
        if (i.repr == "@nil" || i.repr == "nil")
        {
            pushInstr(func, Instr(Opcode.push, cast(uint) func.constants.length));

            func.constants ~= Dynamic.nil;
        }
        else if (i.repr == "true")
        {
            pushInstr(func, Instr(Opcode.push, cast(uint) func.constants.length));

            func.constants ~= dynamic(true);
        }
        else if (i.repr == "false")
        {
            pushInstr(func, Instr(Opcode.push, cast(uint) func.constants.length));

            func.constants ~= dynamic(false);
        }
        else if (i.repr.isNumeric)
        {
            pushInstr(func, Instr(Opcode.push, cast(uint) func.constants.length));

            func.constants ~= Dynamic.strToNum(i.repr);
        }
        else
        {
            if (isTarget)
            {
                uint* us = i.repr in func.stab.byName;
                uint v = void;
                if (us !is null)
                {
                    v = *us;
                }
                else
                {
                    v = func.stab.define(i.repr);
                }
                pushInstr(func, Instr(Opcode.push, cast(uint) func.constants.length));
                func.constants ~= dynamic(v);
            }
            else
            {
                uint* us = i.repr in func.stab.byName;
                if (us !is null)
                {
                    pushInstr(func, Instr(Opcode.load, *us));
                }
                else
                {
                    uint v = func.doCapture(i.repr);
                    pushInstr(func, Instr(Opcode.loadc, v));
                }
            }

        }
    }
}
