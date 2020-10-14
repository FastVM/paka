module lang.vm;

import std.stdio;
import std.range;
import std.conv;
import std.algorithm;
import std.json;
import std.traits;
import core.memory;
import core.stdc.stdlib;
import lang.srcloc;
import lang.error;
import lang.dynamic;
import lang.bytecode;
import lang.number;

alias LocalCallback = void delegate(ref size_t index, ref size_t depth,
        ref Dynamic[] stack, ref Dynamic[] locals);

enum string[2][] cmpMap()
{
    return [["oplt", "<"], ["opgt", ">"], ["oplte", "<="], ["opgte", ">="]];
}

enum string[2][] mutMap()
{
    return [["+=", "add"], ["-=", "sub"], ["*=", "mul"], ["/=", "div"], ["%=", "mod"]];
}

alias allocateStackAllowed = alloca;

Span[] spans;

Dynamic run(T...)(Function func, Dynamic[] args = null, T rest = T.init)
{
    static foreach (I; T)
    {
        static assert(is(I == LocalCallback));
    }
    size_t index = 0;
    size_t depth = 0;
    Dynamic* stack = void;
    Dynamic* locals = void;
    scope (failure)
    {
        spans ~= func.spans[index];
    }
    if (func.flags & Function.Flags.isLocal)
    {
        locals = cast(Dynamic*) GC.malloc((func.stab.byPlace.length + 1) * Dynamic.sizeof,
                0, typeid(Dynamic));
        stack = (cast(Dynamic*) allocateStackAllowed(func.stackSize * Dynamic.sizeof));
    }
    else
    {
        Dynamic* ptr = cast(Dynamic*) allocateStackAllowed(
                (func.stackSize + func.stab.byPlace.length + 1) * Dynamic.sizeof);
        stack = ptr;
        locals = ptr + func.stackSize;
    }
    foreach (i, v; args)
    {
        locals[i] = v;
    }
    scope (exit)
    {
        static foreach (callback; rest)
        {
            static if (is(typeof(callback) == LocalCallback))
            {
                {
                    Dynamic[] st = stack[0 .. func.stackSize];
                    Dynamic[] lo = locals[func.stackSize .. func.stackSize
                        + func.stab.byPlace.length + 1];
                    callback(index, depth, st, lo);
                }
            }
        }
    }
    Instr* instrs = func.instrs.ptr;
    while (true)
    {
        Instr cur = instrs[index];
        switch (cur.op)
        {
        default:
            // throw new RuntimeException("opcode not found: " ~ cur.op.to!string);
            assert(0);
        case Opcode.nop:
            break;
        case Opcode.push:
            stack[depth++] = func.constants[cur.value];
            break;
        case Opcode.pop:
            depth--;
            break;
        case Opcode.sub:
            Function built = new Function(func.funcs[cur.value]);
            built.captured = null;
            built.parent = func;
            built.captured = new Dynamic*[built.capture.length];
            foreach (i, v; built.capture)
            {
                Function.Capture cap = built.capture[i];
                if (cap.is2)
                {
                    built.captured[i] = func.captured[cap.from];
                }
                else
                {
                    built.captured[i] = &locals[cap.from];
                }
            }
            stack[depth++] = dynamic(built);
            break;
        case Opcode.bind:
            depth--;
            stack[depth - 1].tab[stack[depth]].fun.pro = new Function(
                    stack[depth - 1].tab[stack[depth]].fun.pro);
            stack[depth - 1].tab[stack[depth]].fun.pro.self = [stack[depth - 1]];
            stack[depth - 1] = stack[depth - 1].tab[stack[depth]];
            break;
        case Opcode.call:
            depth -= cur.value;
            Dynamic f = stack[depth - 1];
            switch (f.type)
            {
            case Dynamic.Type.fun:
                stack[depth - 1] = f.fun.fun(stack[depth .. depth + cur.value]);
                break;
            case Dynamic.Type.del:
                stack[depth - 1] = (*f.fun.del)(stack[depth .. depth + cur.value]);
                break;
            case Dynamic.Type.pro:
                if (f.fun.pro.self.length != 0)
                {
                    stack[depth - 1] = run(f.fun.pro,
                            f.fun.pro.self ~ stack[depth .. depth + cur.value]);
                }
                else
                {
                    stack[depth - 1] = run(f.fun.pro, stack[depth .. depth + cur.value]);
                }
                break;
            default:
                throw new TypeException("error: not a function: " ~ f.to!string);
            }
            break;
        case Opcode.upcall:
            size_t end = depth;
            depth--;
            while (stack[depth].type != Dynamic.Type.end)
            {
                depth--;
            }
            Dynamic[] cargs;
            for (size_t i = depth + 1; i < end; i++)
            {
                if (stack[i].type == Dynamic.Type.pac)
                {
                    i++;
                    cargs ~= stack[i].arr;
                }
                else
                {
                    cargs ~= stack[i];
                }
            }
            Dynamic f = stack[depth - 1];
            Dynamic result = void;
            switch (f.type)
            {
            case Dynamic.Type.fun:
                result = f.fun.fun(cargs);
                break;
            case Dynamic.Type.del:
                stack[depth - 1] = (*f.fun.del)(cargs);
                break;
            case Dynamic.Type.pro:
                stack[depth - 1] = run(f.fun.pro, f.fun.pro.self ~ cargs);
                break;
            default:
                throw new TypeException("error: not a function: " ~ f.to!string);
            }
            stack[depth - 1] = result;
            break;
        case Opcode.oplt:
            depth -= 1;
            stack[depth - 1] = dynamic(stack[depth - 1] < stack[depth]);
            break;
        case Opcode.opgt:
            depth -= 1;
            stack[depth - 1] = dynamic(stack[depth - 1] > stack[depth]);
            break;
        case Opcode.oplte:
            depth -= 1;
            stack[depth - 1] = dynamic(stack[depth - 1] <= stack[depth]);
            break;
        case Opcode.opgte:
            depth -= 1;
            stack[depth - 1] = dynamic(stack[depth - 1] >= stack[depth]);
            break;
        case Opcode.opeq:
            depth -= 1;
            stack[depth - 1] = dynamic(stack[depth - 1] == stack[depth]);
            break;
        case Opcode.opneq:
            depth -= 1;
            stack[depth - 1] = dynamic(stack[depth - 1] != stack[depth]);
            break;
        case Opcode.array:
            size_t end = depth;
            depth--;
            while (stack[depth].type != Dynamic.Type.end)
            {
                depth--;
            }
            Dynamic[] arr;
            for (size_t i = depth + 1; i < end; i++)
            {
                if (stack[i].type == Dynamic.Type.pac)
                {
                    i++;
                    arr ~= stack[i].arr;
                }
                else
                {
                    arr ~= stack[i];
                }
            }
            stack[depth] = dynamic(arr);
            depth++;
            break;
        case Opcode.targeta:
            size_t end = depth;
            depth--;
            while (stack[depth].type != Dynamic.Type.end)
            {
                depth--;
            }
            stack[depth] = dynamic(stack[depth + 1 .. end].dup);
            depth++;
            break;
        case Opcode.unpack:
            stack[depth++] = dynamic(Dynamic.Type.pac);
            break;
        case Opcode.table:
            size_t end = depth;
            while (stack[depth - 1].type != Dynamic.Type.end)
            {
                depth--;
            }
            Dynamic[Dynamic] table;
            for (size_t i = depth; i < end; i += 2)
            {
                if (stack[i].type == Dynamic.Type.pac)
                {
                    foreach (kv; stack[i + 1].tab.byKeyValue)
                    {
                        table[kv.key] = kv.value;
                    }
                }
                else
                {
                    table[stack[i]] = stack[i + 1];
                }
            }
            stack[depth - 1] = dynamic(table);
            break;
        case Opcode.index:
            depth--;
            Dynamic arr = stack[depth - 1];
            switch (arr.type)
            {
            case Dynamic.Type.arr:
                stack[depth - 1] = (arr.arr)[stack[depth].as!size_t];
                break;
            case Dynamic.Type.tab:
                stack[depth - 1] = (arr.tab)[stack[depth]];
                break;
            default:
                throw new TypeException("error: cannot store at index on a " ~ arr.type.to!string);
            }
            break;
        case Opcode.opneg:
            stack[depth - 1] = -stack[depth - 1];
            break;
        case Opcode.opadd:
            depth--;
            stack[depth - 1] += stack[depth];
            break;
        case Opcode.opsub:
            depth--;
            stack[depth - 1] -= stack[depth];
            break;
        case Opcode.opmul:
            depth--;
            stack[depth - 1] *= stack[depth];
            break;
        case Opcode.opdiv:
            depth--;
            stack[depth - 1] /= stack[depth];
            break;
        case Opcode.opmod:
            depth--;
            stack[depth - 1] %= stack[depth];
            break;
        case Opcode.load:
            stack[depth++] = locals[cur.value];
            break;
        case Opcode.loadc:
            stack[depth++] = *func.captured[cur.value];
            break;
        case Opcode.store:
            locals[cur.value] = stack[depth - 1];
            depth--;
            break;
        case Opcode.istore:
            switch (stack[depth - 3].type)
            {
            case Dynamic.Type.arr:
                (*stack[depth - 3].arrPtr)[stack[depth - 2].as!size_t] = stack[depth - 1];
                break;
            case Dynamic.Type.tab:
                stack[depth - 3].tab[stack[depth - 2]] = stack[depth - 1];
                break;
            default:
                throw new TypeException(
                        "error: cannot store at index on a " ~ stack[depth - 3].type.to!string);
            }
            depth -= 3;
            break;
        case Opcode.opstore:
        switchOpp:
            switch (func.instrs[++index].value)
            {
            default:
                assert(0);
                static foreach (opm; mutMap)
                {
            case opm[1].to!AssignOp:
                    mixin("locals[cur.value]" ~ opm[0] ~ " stack[depth - 1];");
                    break switchOpp;
                }
            }
            depth--;
            break;
        case Opcode.opistore:
        switchOpi:
            switch (func.instrs[index].value)
            {
            default:
                assert(0);
                static foreach (opm; mutMap)
                {
            case opm[1].to!AssignOp:
                    Dynamic arr = stack[depth - 3];
                    switch (arr.type)
                    {
                    case Dynamic.Type.arr:
                        mixin("(*arr.arrPtr)[stack[depth-2].as!size_t]" ~ opm[0]
                                ~ " stack[depth-1];");
                        break switchOpi;
                    case Dynamic.Type.tab:
                        mixin("arr.tab[stack[depth-2]]" ~ opm[0] ~ " stack[depth-1];");
                        break switchOpi;
                    default:
                        throw new TypeException(
                                "error: cannot store at index on a " ~ arr.type.to!string);
                    }
                }
            }
            depth -= 3;
            break;
        case Opcode.retval:
            Dynamic v = stack[--depth];
            return v;
        case Opcode.retnone:
            return Dynamic.nil;
        case Opcode.iftrue:
            Dynamic val = stack[--depth];
            if (val.type != Dynamic.Type.nil && (val.type != Dynamic.Type.log || val.log))
            {
                index = cur.value;
            }
            break;
        case Opcode.iffalse:
            Dynamic val = stack[--depth];
            if (val.type == Dynamic.Type.nil || (val.type == Dynamic.Type.log && !val.log))
            {
                index = cur.value;
            }
            break;
        case Opcode.jump:
            index = cur.value;
            break;
        case Opcode.argno:
            stack[depth] = args[cur.value];
            depth++;
        }
        index++;
    }
    assert(0);
}
