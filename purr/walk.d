module purr.walk;

import purr.ast;
import purr.base;
import purr.bytecode;
import purr.dynamic;
import purr.ssize;
import purr.srcloc;
import std.algorithm;
import std.conv;
import std.string;
import std.stdio;

Node delegate(Node[])[string] transformers;

enum string[] specialForms = [
        "@def", "@set", "@opset", "@while", "@array", "@table", "@return",
        "@if", "@fun", "@do", "@using", "-", "+", "*", "/", "@dotmap-both",
        "@dotmap-lhs", "@dotmap-rhs", "@dotmap-pre", "%", "<", ">", "<=",
        ">=", "==", "!=", "...", "@index", "=>", "|>", "<|", "@using", "@env",
        "&&", "||", "@alias",
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
    Span[] nodes = [Span.init];
    size_t identc;
    string[] envs;
    size_t envc;

    Function walkProgram(Node node, size_t ctx)
    {
        envc = 0;
        func = new Function;
        func.parent = ctx.baseFunction;
        foreach (i; ctx.rootBase)
        {
            func.captab.define(i.name);
        }
        walk(node);
        pushInstr(func, Opcode.retval);
        func.stackSize = stackSize[1];
        func.resizeStack;
        return func;
    }

    string genIdent()
    {
        identc++;
        return "_ident" ~ identc.to!string;
    }

    void modifyInstruction(T)(T index, ushort v)
    {
        func.instrs[index - 2 .. index] = *cast(ubyte[2]*)&v;
    }

    void pushInstr(Function func, Opcode op, ushort[] shorts = null, int size = 0)
    {
        func.stackAt[func.instrs.length] = stackSize[0];
        func.instrs ~= cast(ubyte) op;
        foreach (i; shorts)
        {
            func.instrs ~= *cast(ubyte[2]*)&i;
        }
        func.spans ~= nodes[$ - 1];
        int* psize = op in opSizes;
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
        if (specialForms.canFind(ident.repr) || (ident.repr.length != 0 && ident.repr[0] == '@'))
        {
            return true;
        }
        return false;
    }

    void doPop()
    {
        pushInstr(func, Opcode.pop);
    }

    void walk(Node node)
    {
        if (node.span.last.line != 0)
        {
            nodes ~= node.span;
        }
        scope (exit)
        {
            if (node.span.last.line != 0)
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
            assert(0);
        }
    }

    void walkDef(Node[] args)
    {
        if (args[0].id == "ident")
        {
            Ident ident = cast(Ident) args[0];
            uint place = void;
            if (ident.repr.length > 0 && ident.repr[0] == '.')
            {
                size_t pos = 0;
                while (pos < ident.repr.length && ident.repr[pos] == '.')
                {
                    pos++;
                }
                Node envv = new Ident(envs[$ - pos]);
                walk(envv);
                Node at = new String(ident.repr[pos .. $]);
                walk(at);
                walk(args[1]);
                pushInstr(func, Opcode.istore);
            }
            else
            {
                place = func.stab.define(ident.repr);
                walk(args[1]);
                pushInstr(func, Opcode.store, [cast(ushort) place]);
            }
            pushInstr(func, Opcode.push, [cast(ushort) func.constants.length]);
            func.constants ~= Dynamic.nil;
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
            pushInstr(func, Opcode.push, [cast(ushort) func.constants.length]);
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
        pushInstr(func, Opcode.iffalse, [ushort.max]);
        size_t ifloc = func.instrs.length;
        walk(args[1]);
        pushInstr(func, Opcode.jump, [ushort.max]);
        size_t jumploc = func.instrs.length;
        modifyInstruction(ifloc, cast(ushort)(func.instrs.length));
        walk(args[2]);
        modifyInstruction(jumploc, cast(ushort)(func.instrs.length));
    }

    void walkWhile(Node[] args)
    {
        size_t redo = func.instrs.length;
        walk(args[0]);
        pushInstr(func, Opcode.iffalse, [ushort.max]);
        size_t whileloc = func.instrs.length;
        walk(args[1]);
        doPop;
        pushInstr(func, Opcode.jump, [cast(ushort) redo]);
        modifyInstruction(whileloc, cast(ushort)(func.instrs.length));
        pushInstr(func, Opcode.push, [cast(ushort) func.constants.length]);
        func.constants ~= Dynamic.nil;
    }

    void walkArrowFun(Node[] args)
    {
        if (args.length == 1)
        {
            args = cast(Node) new Call(null) ~ args;
        }
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
            // newFunc.stab.set(argid.repr, cast(uint) 0);
            newFunc.args = [argid.repr];
            walk(args[1]);
            pushInstr(func, Opcode.retval);
            newFunc.stackSize = stackSize[1];
            stackSize = stackOld;
            func = last;
            pushInstr(func, Opcode.sub, [cast(ushort) func.funcs.length]);

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
        foreach (i, v; argl.args)
        {
            Ident id = cast(Ident) v;
            newFunc.args ~= id.repr;
        }
        func = newFunc;
        func.parent = lastFunc;
        foreach (i, v; args[1 .. $])
        {
            if (i != 0)
            {
                doPop;
            }
            walk(v);
        }
        pushInstr(func, Opcode.retval);
        func.stackSize = stackSize[1];
        func.resizeStack;
        stackSize = stackOld;
        func = lastFunc;
        pushInstr(func, Opcode.sub, [cast(ushort) func.funcs.length]);
        func.funcs ~= newFunc;
    }

    void walkBinary(string op)(Node[] args)
    {
        walk(args[0]);
        walk(args[1]);
        pushInstr(func, mixin("Opcode.op" ~ op));
    }

    void walkUnary(string op)(Node[] args)
    {
        walk(args[0]);
        pushInstr(func, mixin("Opcode.op" ~ op));
    }

    void walkSetLeft(Node left)
    {
        if (Call call = cast(Call) left)
        {
            Ident id = cast(Ident) call.args[0];
            switch (id.repr)
            {
            case "@index":
                walk(call.args[1]);
                walk(call.args[2]);
                break;
            case "@array":
                foreach_reverse (arg; call.args[1 .. $])
                {
                    walkSetLeft(arg);
                }
                break;
            default:
                assert(0);
            }
        }
        else if (Ident ident = cast(Ident) left)
        {
            if (ident.repr.length > 0 && ident.repr[0] == '.')
            {
                size_t pos = 0;
                while (pos < ident.repr.length && ident.repr[pos] == '.')
                {
                    pos++;
                }
                Node envv = new Ident(envs[$ - pos]);
                walk(envv);
                Node at = new String(ident.repr[pos .. $]);
                walk(at);
            }
        }
        else
        {
            throw new Exception("internal error");
        }
    }

    void walkSetMatch(Node left, Node right)
    {
        if (Call call = cast(Call) left)
        {
            Ident id = cast(Ident) call.args[0];
            switch (id.repr)
            {
            case "@index":
                walk(right);
                break;
            case "@array":
                foreach (arg; (cast(Call) right).args[1 .. $])
                {
                    walk(arg);
                }
                break;
            default:
                assert(0);
            }
        }
        else if (Ident ident = cast(Ident) left)
        {
            walk(right);
        }
        else
        {
            throw new Exception("internal error");
        }
    }

    void walkSetFinal(Node left,)
    {
        if (Call call = cast(Call) left)
        {
            Ident id = cast(Ident) call.args[0];
            switch (id.repr)
            {
            case "@index":
                pushInstr(func, Opcode.istore);
                break;
            case "@array":
                foreach_reverse (arg; call.args[1 .. $])
                {
                    walkSetFinal(arg);
                }
                break;
            default:
                assert(0);
            }
        }
        else if (Ident ident = cast(Ident) left)
        {
            if (ident.repr.length > 0 && ident.repr[0] == '.')
            {
                pushInstr(func, Opcode.istore);
            }
            else
            {
                immutable(uint)* us = ident.repr in func.stab.byNameImmutable;
                if (us is null)
                {
                    us = new uint(func.stab.define(ident.repr));
                }
                pushInstr(func, Opcode.store, [cast(ushort)*us]);
            }
        }
        else
        {
            throw new Exception("internal error");
        }
    }

    void walkOpSetFinal(Ident opid, Node left)
    {
        if (Call call = cast(Call) left)
        {
            Ident id = cast(Ident) call.args[0];
            switch (id.repr)
            {
            case "@index":
                pushInstr(func, Opcode.opistore, [opid.repr.to!AssignOp]);
                break;
            case "@array":
                foreach_reverse (arg; call.args[1 .. $])
                {
                    walkOpSetFinal(opid, arg);
                }
                break;
            default:
                assert(0);
            }
        }
        else if (Ident ident = cast(Ident) left)
        {
            if (ident.repr.length > 0 && ident.repr[0] == '.')
            {
                pushInstr(func, Opcode.opistore, [opid.repr.to!AssignOp]);
            }
            else
            {
                immutable(uint)* us = ident.repr in func.stab.byNameImmutable;
                if (us is null)
                {
                    us = new uint(func.stab.define(ident.repr));
                }
                pushInstr(func, Opcode.opstore, [
                        cast(ushort)*us, cast(ushort) opid.repr.to!AssignOp
                        ]);
            }
        }
        else
        {
            throw new Exception("internal error");
        }
    }

    void walkSet(Node[] args)
    {
        walkSetLeft(args[0]);
        walkSetMatch(args[0], args[1]);
        walkSetFinal(args[0]);
        pushInstr(func, Opcode.push, [cast(ushort) func.constants.length]);
        func.constants ~= Dynamic.nil;
    }

    void walkOpSet(Node[] args)
    {
        walkSetLeft(args[1]);
        walkSetMatch(args[1], args[2]);
        walkOpSetFinal(cast(Ident) args[0], args[1]);
        pushInstr(func, Opcode.push, [cast(ushort) func.constants.length]);
        func.constants ~= Dynamic.nil;
    }

    void walkAlias(Node[] args)
    {
        Ident id = cast(Ident) args[0];
        Call lambda = new Call(new Ident("@fun"), [new Call(null), args[1]]);
        walk(lambda);
        Function.Lookup.Flags flags = Function.Lookup.Flags.callImplicit
            | Function.Lookup.Flags.noAssign;
        uint us = func.stab.define(id.repr, flags);
        pushInstr(func, Opcode.store, [cast(ushort) us]);
        pushInstr(func, Opcode.push, [cast(ushort) func.constants.length]);
        func.constants ~= Dynamic.nil;
    }

    void walkReturn(Node[] args)
    {
        if (args.length == 0)
        {
            pushInstr(func, Opcode.retnone);
        }
        else
        {
            walk(args[0]);
            pushInstr(func, Opcode.retval);
            doPop;

        }
    }

    void walkArray(Node[] args)
    {
        uint tmp = stackSize[0];
        pushInstr(func, Opcode.push, [cast(ushort) func.constants.length]);
        func.constants ~= dynamic(Dynamic.Type.end);
        int used = stackSize[0];
        foreach (i; args)
        {
            walk(i);
        }
        pushInstr(func, Opcode.array);
        stackSize[0] = tmp + 1;
    }

    void walkTable(Node[] args)
    {
        uint tmp = stackSize[0];
        pushInstr(func, Opcode.push, [cast(ushort) func.constants.length]);
        func.constants ~= dynamic(Dynamic.Type.end);
        uint used = stackSize[0];
        foreach (i; args)
        {
            walk(i);
        }
        pushInstr(func, Opcode.table, null, stackSize[0] - used);
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
        walk(args[0]);
        walk(args[1]);
        pushInstr(func, Opcode.index);
    }

    void walkUnpack(Node[] args)
    {
        pushInstr(func, Opcode.unpack);
        walk(args[0]);
    }

    // void walkDotmap(string s)(Node[] args)
    // {
    //     static if (s == "_pre_map")
    //     {
    //         Node[] xy = [new Ident("_rhs")];
    //         Node lambdaBody = new Call([args[0]] ~ xy);
    //         Call lambda = new Call(new Ident("@fun"), [new Call(xy), lambdaBody]);
    //         Call domap = new Call(new Ident(s), [cast(Node) lambda] ~ args[1 .. $]);
    //         walk(domap);
    //     }
    //     else
    //     {
    //         Node[] xy = [new Ident("_lhs"), new Ident("_rhs")];
    //         Node lambdaBody = new Call(args[0 .. $ - 2] ~ xy);
    //         Call lambda = new Call(new Ident("@fun"), [new Call(xy), lambdaBody]);
    //         Call domap = new Call(new Ident(s), [cast(Node) lambda] ~ args[$ - 2 .. $]);
    //         walk(domap);
    //     }
    // }

    void walkPipeOp(Node[] args)
    {
        walk(new Call(args[1], [args[0]]));
    }

    void walkRevPipeOp(Node[] args)
    {
        walk(new Call(args[0], [args[1]]));
    }

    void walkUsing(Node[] args)
    {
        envs ~= genIdent;
        scope (exit)
        {
            envs.length--;
        }
        Node id = new Ident(envs[$ - 1]);
        walk(new Call(new Ident("@set"), [id, args[0]]));
        doPop;
        walk(args[1]);
        doPop;
        walk(id);
    }

    void walkLogicalAnd(Node[] args)
    {
        walk(new Call(new Ident("@if"), [args[0], args[1], new Ident("false")]));
    }

    void walkLogicalOr(Node[] args)
    {
        walk(new Call(new Ident("@if"), [args[0], new Ident("true"), args[1]]));
    }

    void walkSpecialCall(Call c)
    {
        switch ((cast(Ident) c.args[0]).repr)
        {
        default:
            walkUnknownSpecialCall((cast(Ident) c.args[0]).repr, c.args[1 .. $]);
            break;
        case "@def":
            walkDef(c.args[1 .. $]);
            break;
        case "@fun":
            walkFun(c.args[1 .. $]);
            break;
        case "=>":
            walkArrowFun(c.args[1 .. $]);
            break;
        case "<|":
            walkRevPipeOp(c.args[1 .. $]);
            break;
        case "|>":
            walkPipeOp(c.args[1 .. $]);
            break;
        case "@alias":
            walkAlias(c.args[1 .. $]);
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
        case "@using":
            walkUsing(c.args[1 .. $]);
            break;
        // case "@paka.dotmap-both":
        //     walkDotmap!"_both_map"(c.args[1 .. $]);
        //     break;
        // case "@paka.dotmap-lhs":
        //     walkDotmap!"_lhs_map"(c.args[1 .. $]);
        //     break;
        // case "@paka.dotmap-rhs":
        //     walkDotmap!"_rhs_map"(c.args[1 .. $]);
        //     break;
        // case "@paka.dotmap-pre":
        //     walkDotmap!"_pre_map"(c.args[1 .. $]);
        //     break;
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
        case "&&":
            walkLogicalAnd(c.args[1 .. $]);
            break;
        case "||":
            walkLogicalOr(c.args[1 .. $]);
            break;
        case "...":
            walkUnpack(c.args[1 .. $]);
            break;
        }
    }

    void walkUnknownSpecialCall(string name, Node[] args)
    {
        Node delegate(Node[])* transform = name in transformers;
        if (transform !is null)
        {
            walk((*transform)(args));
        }
        else
        {
            throw new Exception("Unknown special call: " ~ name);
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
                pushInstr(func, Opcode.push, [cast(ushort) func.constants.length]);
                func.constants ~= dynamic(Dynamic.Type.end);
                foreach (i; c.args[1 .. $])
                {
                    walk(i);
                }
                pushInstr(func, Opcode.upcall, [], used);

            }
            else
            {
                walk(c.args[0]);
                uint used = stackSize[0];
                foreach (i; c.args[1 .. $])
                {
                    walk(i);
                }
                pushInstr(func, Opcode.call, [cast(ushort)(c.args.length - 1)], used);

            }
        }
    }

    void walkExact(String s)
    {
        pushInstr(func, Opcode.push, [cast(ushort) func.constants.length]);
        func.constants ~= dynamic(nameFormat(s.repr));
    }

    string nameFormat(string input)
    {
        string irepr;
        size_t index;
        while (index < input.length)
        {
            char cur = input[index];
            stdout.flush;
            if (cur == '\\')
            {
                index++;
                cur = input[index];
                irepr ~= cur;
            }
            else if (cur == '{')
            {
                index++;
                string num;
                while (true)
                {
                    cur = input[index];
                    if (cur == '}')
                    {
                        break;
                    }
                    num ~= cur;
                    index++;
                }
                double asNumber = num.to!double;
                if (asNumber % 1 != 0)
                {
                    throw new Exception("invalid string escape: {" ~ num ~ "}");
                }
                else if (char.min > asNumber || asNumber >= char.max) {
                    throw new Exception("invalid string escape: not ascii: {" ~ num ~ "}");
                }
                irepr ~= cast(char) asNumber;
            }
            else
            {
                irepr ~= cur;
            }
            index++;
        }
        return irepr;
    }

    void walkExact(Ident i)
    {
        string irepr = nameFormat(i.repr);
        if (irepr == "@nil" || irepr == "nil")
        {
            pushInstr(func, Opcode.push, [cast(ushort) func.constants.length]);
            func.constants ~= Dynamic.nil;
        }
        else if (irepr == "true")
        {
            pushInstr(func, Opcode.push, [cast(ushort) func.constants.length]);
            func.constants ~= dynamic(true);
        }
        else if (irepr == "false")
        {
            pushInstr(func, Opcode.push, [cast(ushort) func.constants.length]);
            func.constants ~= dynamic(false);
        }
        else if (irepr == "$args")
        {
            pushInstr(func, Opcode.args);
        }
        else if (irepr.length != 0 && irepr[0] == '$' && irepr[1 .. $].isNumeric)
        {
            pushInstr(func, Opcode.argno, [irepr[1 .. $].to!ushort]);
        }
        else if (irepr.length != 0 && irepr[0] == '.')
        {
            size_t pos = 0;
            while (pos < irepr.length && irepr[pos] == '.')
            {
                pos++;
            }
            Node envv = new Ident(envs[$ - pos]);
            Node node = new Call(new Ident("@index"), [
                    envv, new String(irepr[pos .. $])
                    ]);
            walk(node);
        }
        else if (irepr.isNumeric)
        {
            pushInstr(func, Opcode.push, [cast(ushort) func.constants.length]);
            func.constants ~= Dynamic.strToNum(irepr);
        }
        else
        {
            bool unfound = true;
            foreach (argno, argname; func.args)
            {
                if (argname == irepr)
                {
                    pushInstr(func, Opcode.argno, [cast(ushort) argno]);
                    unfound = false;
                }
            }
            if (unfound)
            {
                immutable(uint)* us = irepr in func.stab.byNameImmutable;
                Function.Lookup.Flags flags = void;
                if (us !is null)
                {
                    pushInstr(func, Opcode.load, [cast(ushort)*us]);
                    flags = func.stab.flags(irepr);
                }
                else
                {
                    uint v = func.doCapture(irepr);
                    pushInstr(func, Opcode.loadc, [cast(ushort) v]);
                    flags = func.captab.flags(irepr);
                }
                if (flags & Function.Lookup.Flags.callImplicit)
                {
                    uint used = stackSize[0];
                    pushInstr(func, Opcode.call, [0], used);
                }
            }
        }
    }
}
