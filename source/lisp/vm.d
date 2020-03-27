module lisp.vm;

import lisp.dynamic: Dynamic;
import lisp.bytecode: Function;
Dynamic run(Function func, Dynamic[] args) {
    import core.memory: GC;
    import lisp.dynamic: Dynamic, dynamic, nil;
    import lisp.bytecode: Instr, Opcode;
    import std.stdio: writeln;
    uint index = 0;
    uint depth = 0;
    size_t locc = (args.length+func.stab.byPlace.length+func.capture.length);
    Dynamic* stack = cast(Dynamic*) GC.malloc(Dynamic.sizeof * (func.stackSize + locc));
    Dynamic* locals = stack + locc;
    foreach (i, v; args) {
        locals[i] = v;
    }
    foreach (i; func.capture) {
        locals[i.to] = func.captured[i.from];
    }
    while (true) {
        Instr cur = func.instrs[index];
        final switch (cur.op) {
        case Opcode.push:
            stack[depth++] = func.constants[cur.value];
            break;
        case Opcode.pop:
            depth --;
            break;
        case Opcode.call:
            depth -= cur.value;
            Dynamic f = stack[depth-1];
            switch(f.type) {
            case Dynamic.Type.fun:
                stack[depth-1] = f.value.fun.fun(stack[depth..depth+cur.value]);
                break;
            case Dynamic.Type.del:
                stack[depth-1] = (*f.value.fun.del)(stack[depth..depth+cur.value]);
                break;
            case Dynamic.Type.pro:
                stack[depth-1] = run(f.value.fun.pro, stack[depth..depth+cur.value]);
                break;
            default:
                throw new Exception("Type error: not a function");
            }
            break;
        case Opcode.func:
            Function built = new Function(func.funcs[cur.value]);
            built.captured = locals;
            stack[depth++] = dynamic(built);
            break;
        case Opcode.load:
            stack[depth++] = locals[cur.value];
            break;
        case Opcode.store:
            locals[cur.value] = stack[depth-1];
            break;
        case Opcode.retval:
            return stack[depth-1];
        case Opcode.retnone:
            return nil;
        case Opcode.iftrue:
            Dynamic val = stack[--depth];
            if (val.type != Dynamic.Type.nil && (val.type != Dynamic.Type.log || val.value.log)) {
                index = cur.value;
            }
            break;
        case Opcode.jump:
            index = cur.value;
            break;
        }
        index ++;
    }
}