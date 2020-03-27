module lisp.walk;

class Walker {
    import lisp.parse: Node, Call, Atom, String, Ident, Number, NodeTypes;
    import lisp.bytecode: Function, Instr, Opcode;
    Function func;
    ushort[2] stackSize;
    enum string[] specialForms = [
        "def",
        "if",
        "fun",
        "do",
    ];
    Function walkProgram(Node node) {
        import lisp.base: baseFunction;
        func = new Function;
        func.parent = baseFunction;
        walk(node);
        func.instrs ~= Instr(Opcode.retnone);
        func.stackSize = stackSize[1];
        return func;
    }
    void freeStack(size_t n = 1) {
        stackSize[0] -= n;
    }
    void useStack(size_t n = 1) {
        stackSize[0] += n;
        if (stackSize[0] > stackSize[1]) {
            stackSize[1] = stackSize[0];
        }
    }
    bool isSpecialCall(Node node) {
        import lisp.parse: Ident;
        import std.algorithm: canFind;
        if (typeid(node) != typeid(Ident)) {
            return false;
        }
        Ident ident = cast(Ident) node;
        if (!specialForms.canFind(ident.repr)) {
            return false;
        }
        return true;
    }
    void walk(Node node) {
        TypeInfo info = typeid(node);
        static foreach (T; NodeTypes) {
            if (info == typeid(T)) {
                walkExact(cast(T) node);
                return;
            }
        }
    }
    void walkDefine(Node[] args) {
        if (typeid(args[0]) == typeid(Ident)) {
            Ident ident = cast(Ident) args[0];
            ushort place = func.stab.define(ident.repr);
            walk(args[1]);
            func.instrs ~= Instr(Opcode.store, place);
        }
        else {
            Call callArgs = cast(Call) args[0];
            Node name = callArgs.args[0];
            Call funArgs = new Call(callArgs.args[1..$]);
            Call funCall = new Call(new Ident("fun"),  funArgs ~ args[1..$]);
            Call newDefine = new Call(new Ident("def"), [name, funCall]);
            walk(newDefine);
        }
    }
    void walkDo(Node[] args) {
        foreach (i, v; args) {
            if (i != 0) {
                func.instrs ~= Instr(Opcode.pop);
                freeStack;
            }
            walk(v);
        }
    }
    void walkIf(Node[] args) {
        walk(args[0]);
        size_t ifloc = func.instrs.length;
        func.instrs ~= Instr(Opcode.iftrue);
        freeStack;
        walk(args[2]);
        func.instrs[ifloc].value = cast(ushort) func.instrs.length;
        size_t jumploc = func.instrs.length;
        func.instrs ~= Instr(Opcode.jump);
        walk(args[1]);
        func.instrs[jumploc].value = cast(ushort)(func.instrs.length - 1);
    }
    void walkFun(Node[] args) {
        Call argl = cast(Call) args[0];
        Function last = func;
        ushort[2] stackOld = stackSize;
        stackSize = [0, 0];
        Function newFunc = new Function;
        func = newFunc;
        func.parent = last;
        foreach (i, v; argl.args) {
            Ident id = cast(Ident) v;
            newFunc.stab.set(id.repr, cast(ushort) i);
        }
        foreach (i, v; args[1..$]) {
            if (i != 0) {
                newFunc.instrs ~= Instr(Opcode.pop);
                freeStack;
            }
            walk(v);
        }
        newFunc.instrs ~= Instr(Opcode.retval);
        newFunc.stackSize = stackSize[1];
        stackSize = stackOld;
        last.instrs ~= Instr(Opcode.func, cast(ushort) last.funcs.length);
        useStack;
        last.funcs ~= newFunc;
        func = last;
    }
    void walkSpecialCall(Call c) {
        final switch ((cast(Ident) c.args[0]).repr) {
        case "def":
            return walkDefine(c.args[1..$]);
        case "fun":
            return walkFun(c.args[1..$]);
        case "do":
            return walkDo(c.args[1..$]);
        case "if":
            return walkIf(c.args[1..$]);
        }
    }
    void walkExact(Call c) {
        if (isSpecialCall(c.args[0])) {
            walkSpecialCall(c);
        }
        else {
            walk(c.args[0]);
            foreach (i; c.args[1..$]) {
                walk(i);
            }
            func.instrs ~= Instr(Opcode.call, cast(ushort)(c.args.length-1));
            freeStack(c.args.length-1);
        }
    }
    void walkExact(String s) {
        import lisp.dynamic: Dynamic, dynamic;
        func.instrs ~= Instr(Opcode.push, cast(ushort) func.constants.length);
        useStack;
        func.constants ~= dynamic(s.repr);
    }
    void walkExact(Number n) {
        import lisp.dynamic: Dynamic, dynamic;
        import std.conv: to;
        func.instrs ~= Instr(Opcode.push, cast(ushort) func.constants.length);
        useStack;
        func.constants ~= dynamic(n.repr.to!double);
    }
    void walkExact(Ident i) {
        import lisp.dynamic: Dynamic, dynamic;
        import std.string: isNumeric;
        import std.conv: to;
        if (i.repr.isNumeric) {
            func.instrs ~= Instr(Opcode.push, cast(ushort) func.constants.length);
            useStack;
            func.constants ~= dynamic(i.repr.to!double);
        }
        else {
            func.instrs ~= Instr(Opcode.load, func.useName(i.repr));
            useStack;
        }
    }
}