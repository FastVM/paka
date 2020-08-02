module lang.walk;

import lang.ast;
import lang.bytecode;
import lang.dynamic;
import lang.base;
import lang.ssize;
import std.algorithm;
import std.conv;
import std.string;
import std.stdio;

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
    ushort[2] stackSize;
    ushort used;
    bool isTarget = false;
    enum string[] specialForms = [
            "@def", "@set", "@opset", "@while", "@array", "@table", "@target",
            "@return", "@if", "@fun", "@do", "@using", "+", "-", "*", "/",
            "%", "<", ">", "<=", ">=", "==", "!=", "...", "@index", "@method",
            "=>", "."
        ];
    Function walkProgram(Node node)
    {
        func = new Function;
        func.parent = baseFunction;
        foreach (i; rootBase)
        {
            func.captab.define(i.name);
        }
        walk(node);
        func.instrs ~= Instr(Opcode.retval);
        func.stackSize = stackSize[1];
        // foreach(k,i; func.instrs) {
        //     writeln(k,":",i);
        // }
        func.resizeStack;
        return func;
    }

    void freeStack(size_t n = 1)
    {
        stackSize[0] -= n;
    }

    void useStack(size_t n = 1)
    {
        stackSize[0] += n;
        if (stackSize[0] > stackSize[1])
        {
            stackSize[1] = stackSize[0];
        }
    }

    bool isSpecialCall(Node node)
    {
        if (typeid(node) != typeid(Ident))
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
        func.instrs ~= Instr(Opcode.pop);
    }

    void walk(Node node)
    {
        TypeInfo info = typeid(node);
        foreach (T; NodeTypes)
        {
            if (info == typeid(T))
            {
                walkExact(cast(T) node);
                // writeln(stackSize[0], " => ", node);
                return;
            }
        }
    }

    void walkDef(Node[] args)
    {
        if (typeid(args[0]) == typeid(Ident))
        {
            Ident ident = cast(Ident) args[0];
            ushort place = func.stab.define(ident.repr);
            walk(args[1]);
            func.instrs ~= Instr(Opcode.store, place);
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
            func.instrs ~= Instr(Opcode.push, cast(ushort) func.constants.length);
            useStack;
            func.constants ~= Dynamic.nil;
        }
        foreach (i, v; args)
        {
            if (i != 0)
            {
                doPop;
                freeStack;
            }
            walk(v);
        }
    }

    void walkIf(Node[] args)
    {
        walk(args[0]);
        size_t ifloc = func.instrs.length;
        func.instrs ~= Instr(Opcode.iffalse);
        freeStack;
        walk(args[1]);
        func.instrs[ifloc].value = cast(ushort) func.instrs.length;
        size_t jumploc = func.instrs.length;
        func.instrs ~= Instr(Opcode.jump);
        walk(args[2]);
        func.instrs[jumploc].value = cast(ushort)(func.instrs.length - 1);
    }

    void walkWhile(Node[] args)
    {
        size_t redo = func.instrs.length - 1;
        walk(args[0]);
        size_t whileloc = func.instrs.length;
        func.instrs ~= Instr(Opcode.iffalse);
        freeStack;
        walk(args[1]);
        doPop;
        freeStack;
        func.instrs ~= Instr(Opcode.jump, cast(ushort) redo);
        func.instrs[whileloc].value = cast(ushort)(func.instrs.length - 1);
        func.instrs ~= Instr(Opcode.push, cast(ushort) func.constants.length);
        useStack;
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
            ushort[2] stackOld = stackSize;
            stackSize = [0, 0];
            Function newFunc = new Function;
            func = newFunc;
            func.parent = last;
            newFunc.stab.set(argid.repr, cast(ushort) 0);
            walk(args[1]);
            newFunc.instrs ~= Instr(Opcode.retval);
            newFunc.stackSize = stackSize[1];
            stackSize = stackOld;
            last.instrs ~= Instr(Opcode.sub, cast(ushort) last.funcs.length);
            useStack;
            last.funcs ~= newFunc;
            func = last;
            newFunc.resizeStack;
        }
    }

    void walkFun(Node[] args)
    {
        Call argl = cast(Call) args[0];
        Function lastFunc = func;
        ushort lastUsed = used;
        ushort[2] stackOld = stackSize;
        stackSize = [0, 0];
        Function newFunc = new Function;
        func = newFunc;
        func.parent = lastFunc;
        used = 0;
        foreach (i, v; argl.args)
        {
            Ident id = cast(Ident) v;
            newFunc.stab.set(id.repr, cast(ushort) i);
        }
        foreach (i, v; args[1 .. $])
        {
            if (i != 0)
            {
                newFunc.instrs ~= Instr(Opcode.pop);
                freeStack;
            }
            walk(v);
        }
        newFunc.instrs ~= Instr(Opcode.retval);
        newFunc.stackSize = stackSize[1];
        stackSize = stackOld;
        lastFunc.instrs ~= Instr(Opcode.sub, cast(ushort) lastFunc.funcs.length);
        useStack;
        lastFunc.funcs ~= newFunc;
        used = lastUsed;
        func = lastFunc;
        newFunc.resizeStack;
    }

    void walkBinary(string op)(Node[] args)
    {
        walk(args[0]);
        walk(args[1]);
        func.instrs ~= Instr(mixin("Opcode.op" ~ op));
        freeStack;
    }

    void walkUnary(string op)(Node[] args)
    {
        walk(args[0]);
        func.instrs ~= Instr(mixin("Opcode.op" ~ op));
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
                    func.instrs ~= Instr(Opcode.istore);
                    freeStack;
                    break;
                case "@table":
                case "@array":
                    walk(new Call(new Ident("@target"), [call]));
                    func.instrs ~= Instr(Opcode.tstore);
                    freeStack(1);
                    break;
                case ".":
                    if (used == 0)
                    {
                        func.useEnv();
                        func.instrs ~= Instr(Opcode.loadenv);
                        useStack;
                        walk(new String((cast(Ident) call.args[1]).repr));
                        func.instrs ~= Instr(Opcode.istore);
                        freeStack;
                    }
                    else
                    {
                        walkExact(new String((cast(Ident) call.args[1]).repr));
                        func.instrs ~= Instr(Opcode.qstore);
                        freeStack(1);
                    }
                    break;
                default:
                    assert(0);
                }
            }
            else if (Ident ident = cast(Ident) target)
            {
                ushort* us = ident.repr in func.stab.byName;
                if (us is null)
                {
                    ushort place = func.stab.define(ident.repr);
                    func.instrs ~= Instr(Opcode.store, place);
                }
                else
                {
                    func.instrs ~= Instr(Opcode.store, *us);
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
                    func.instrs ~= Instr(Opcode.opistore, id.repr.to!AssignOp);
                    freeStack(2);
                    break;
                case "@table":
                case "@array":
                    walk(new Call(new Ident("@target"), [call]));
                    func.instrs ~= Instr(Opcode.optstore, id.repr.to!AssignOp);
                    freeStack(1);
                    break;
                case ".":
                    if (used == 0)
                    {
                        func.useEnv();
                        func.instrs ~= Instr(Opcode.loadenv);
                        useStack;
                        walk(new String((cast(Ident) call.args[1]).repr));
                        func.instrs ~= Instr(Opcode.opistore, id.repr.to!AssignOp);
                        freeStack;
                    }
                    else
                    {
                        walkExact(new String((cast(Ident) call.args[1]).repr));
                        func.instrs ~= Instr(Opcode.opqstore, id.repr.to!AssignOp);
                        freeStack(1);
                    }
                    break;
                default:
                    assert(0);
                }
            }
            else
            {
                Ident ident = cast(Ident) target;
                ushort* us = ident.repr in func.stab.byName;
                if (us is null)
                {
                    ushort place = func.stab.define(ident.repr);
                    func.instrs ~= Instr(Opcode.opstore, place);
                }
                else
                {
                    func.instrs ~= Instr(Opcode.opstore, *us);
                }
                func.instrs ~= Instr(Opcode.nop, id.repr.to!AssignOp);
            }
        }
    }

    void walkReturn(Node[] args)
    {
        if (args.length == 0)
        {
            func.instrs ~= Instr(Opcode.retnone);
        }
        else
        {
            walk(args[0]);
            func.instrs ~= Instr(Opcode.retval);
            doPop;
            freeStack;
        }
    }

    void walkArray(Node[] args)
    {
        func.instrs ~= Instr(Opcode.push, cast(ushort) func.constants.length);
        useStack;
        func.constants ~= dynamic(Dynamic.Type.end);
        foreach (i; args)
        {
            walk(i);
        }
        if (isTarget)
        {
            func.instrs ~= Instr(Opcode.targeta);
        }
        else
        {
            func.instrs ~= Instr(Opcode.array);
        }
        freeStack(args.length);
    }

    void walkTable(Node[] args)
    {
        foreach (i; args)
        {
            walk(i);
        }
        func.instrs ~= Instr(Opcode.table, cast(ushort) args.length);
        freeStack(args.length);
        useStack();
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
            func.instrs ~= Instr(Opcode.push, cast(ushort) func.constants.length);
            useStack;
            func.constants ~= dynamic(Dynamic.Type.end);
            walk(args[0]);
            walk(args[1]);
            isTarget = true;
            func.instrs ~= Instr(Opcode.targeta);
            freeStack(2);
            func.instrs ~= Instr(Opcode.data);
        }
        else
        {
            walk(args[0]);
            walk(args[1]);
            func.instrs ~= Instr(Opcode.index);
            freeStack;
        }
    }

    void walkUnpack(Node[] args)
    {
        func.instrs ~= Instr(Opcode.unpack);
        useStack;
        walk(args[0]);
    }

    void walkMethod(Node[] args)
    {
        walk(args[0]);
        walk(args[1]);
        func.instrs ~= Instr(Opcode.bind);
        freeStack;
    }

    void walkUsing(Node[] args)
    {
        walk(args[0]);
        func.instrs ~= Instr(Opcode.douse);
        freeStack();
        used++;
        walk(args[1]);
        used--;
        func.instrs ~= Instr(Opcode.unuse);
        useStack();
    }

    void walkUse(Node[] args)
    {
        if (used == 0)
        {
            func.useEnv();
            if (isTarget)
            {
                func.instrs ~= Instr(Opcode.push, cast(ushort) func.constants.length);
                func.constants ~= dynamic(Dynamic.Type.end);
                useStack;
                func.instrs ~= Instr(Opcode.loadenv);
                useStack;
                walk(new String((cast(Ident) args[0]).repr));
                func.instrs ~= Instr(Opcode.targeta);
                freeStack(2);
                func.instrs ~= Instr(Opcode.data);
            }
            else
            {
                func.instrs ~= Instr(Opcode.loadenv);
                useStack;
                walk(new String((cast(Ident) args[0]).repr));
                func.instrs ~= Instr(Opcode.index);
                freeStack;
            }
        }
        else
        {
            walkExact(new String((cast(Ident) args[0]).repr));
            if (!isTarget)
            {
                func.instrs ~= Instr(Opcode.use);
            }
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
        case "@method":
            walkMethod(c.args[1 .. $]);
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
        case "@using":
            walkUsing(c.args[1 .. $]);
            break;
        case ".":
            walkUse(c.args[1 .. $]);
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
                func.instrs ~= Instr(Opcode.push, cast(ushort) func.constants.length);
                useStack;
                func.constants ~= dynamic(Dynamic.Type.end);
                foreach (i; c.args[1 .. $])
                {
                    walk(i);
                }
                func.instrs ~= Instr(Opcode.upcall, cast(ushort)(c.args.length - 1));
                freeStack(c.args.length);
            }
            else
            {
                walk(c.args[0]);
                foreach (i; c.args[1 .. $])
                {
                    walk(i);
                }
                func.instrs ~= Instr(Opcode.call, cast(ushort)(c.args.length - 1));
                freeStack(c.args.length - 1);
            }
        }
    }

    void walkExact(String s)
    {
        func.instrs ~= Instr(Opcode.push, cast(ushort) func.constants.length);
        useStack;
        func.constants ~= dynamic(s.repr);
    }

    void walkExact(Ident i)
    {
        if (i.repr == "@nil" || i.repr == "nil")
        {
            func.instrs ~= Instr(Opcode.push, cast(ushort) func.constants.length);
            useStack;
            func.constants ~= Dynamic.nil;
        }
        else if (i.repr == "true")
        {
            func.instrs ~= Instr(Opcode.push, cast(ushort) func.constants.length);
            useStack;
            func.constants ~= dynamic(true);
        }
        else if (i.repr == "false")
        {
            func.instrs ~= Instr(Opcode.push, cast(ushort) func.constants.length);
            useStack;
            func.constants ~= dynamic(false);
        }
        else if (i.repr.isNumeric)
        {
            func.instrs ~= Instr(Opcode.push, cast(ushort) func.constants.length);
            useStack;
            func.constants ~= dynamic(i.repr.to!Number);
        }
        else
        {
            if (i.repr == "env")
            {
                if (used == 0)
                {
                    func.useEnv();
                    func.instrs ~= Instr(Opcode.loadenv);
                }
                else
                {
                    func.instrs ~= Instr(Opcode.loaduse);
                }
            }
            else if (isTarget)
            {
                ushort* us = i.repr in func.stab.byName;
                ushort v = void;
                if (us !is null)
                {
                    v = *us;
                }
                else
                {
                    v = func.stab.define(i.repr);
                }
                func.instrs ~= Instr(Opcode.push, cast(ushort) func.constants.length);
                func.constants ~= dynamic(v.to!Number);
            }
            else
            {
                ushort* us = i.repr in func.stab.byName;
                if (us !is null)
                {
                    func.instrs ~= Instr(Opcode.load, *us);
                }
                else
                {
                    ushort v = func.doCapture(i.repr);
                    func.instrs ~= Instr(Opcode.loadc, v);
                }
            }
            useStack;
        }
    }
}
