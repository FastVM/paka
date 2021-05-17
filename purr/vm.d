module purr.vm;

import purr.io;
import std.range;
import std.conv;
import std.algorithm;
import std.json;
import std.traits;
import core.memory;
import core.stdc.stdlib;
import purr.srcloc;
import purr.dynamic;
import purr.bytecode;
import purr.bugs;

version = PurrErrors;

DebugFrame[] debugFrames;

alias LocalFormback = void delegate(uint index, Dynamic[] locals);

enum string[2][] cmpMap()
{
    return [["oplt", "<"], ["opgt", ">"], ["oplte", "<="], ["opgte", ">="]];
}

enum string[2][] mutMap()
{
    return [["+", "add"], ["-", "sub"], ["*", "mul"], ["/", "div"], ["%", "mod"], ["~", "cat"]];
}

pragma(inline, true) T eat(T)(ubyte* bytes, ref ushort index)
{
    T ret = *cast(T*)(bytes + index);
    index += T.sizeof;
    return ret;
}

pragma(inline, true) T peek(T)(ubyte* bytes, ref ushort index)
{
    return *cast(T*)(bytes + index);
}

Dynamic run(T...)(Function func, Dynamic[] args = null, T rest = T.init)
{
    static foreach (I; T)
    {
        static assert(is(I == LocalFormback));
    }
    ushort index = 0;
    size_t stackAlloc = (func.stackSize + func.stab.length) * Dynamic.sizeof;
    Dynamic* stack = void;
    if (func.flags & Function.Flags.isLocal || T.length != 0)
    {
        stack = cast(Dynamic*) GC.malloc(stackAlloc);
    }
    else
    {
        stack = cast(Dynamic*) alloca(stackAlloc);
    }
    Dynamic* locals = stack + func.stackSize;
    ubyte* instrs = func.instrs.ptr;
    version (PurrErrors)
    {
        scope (failure)
        {
            debugFrames ~= new DebugFrame(func, index, locals);
        }
    }
    while (true)
    {
        Opcode cur = instrs.eat!Opcode(index);
        switch (cur)
        {
        default:
            assert(false);
        case Opcode.nop:
            break;
        case Opcode.push:
            ushort constIndex = instrs.eat!ushort(index);
            *(++stack) = func.constants[constIndex];
            break;
        case Opcode.pop:
            stack--;
            break;
        case Opcode.rec:
            *(++stack) = func.dynamic;
            break;
        case Opcode.sub:
            Function built = new Function(func.funcs[instrs.eat!ushort(index)]);
            built.parent = func;
            built.captured = new Dynamic*[built.capture.length];
            foreach (i, v; built.capture)
            {
                Function.Capture cap = built.capture[i];
                if (cap.is2)
                {
                    built.captured[i] = func.captured[cap.from];
                }
                else if (cap.isArg)
                {
                    built.captured[i] = new Dynamic(args[cap.from]);
                }
                else
                {
                    built.captured[i] = &locals[cap.from];
                }
            }
            *(++stack) = dynamic(built);
            break;
        case Opcode.call:
            ushort count = instrs.eat!ushort(index);
            stack -= count;
            Dynamic f = *stack;
            switch (f.type)
            {
            case Dynamic.Type.fun:
                *stack = f.fun.fun.value(stack[1 .. 1 + count]);
                break;
            case Dynamic.Type.pro:
                *stack = run(f.fun.pro, stack[1 .. 1 + count]);
                break;
            case Dynamic.Type.tab:
                *stack = f.tab()(stack[1 .. 1 + count]);
                break;
            case Dynamic.Type.tup:
                *stack = f.arr[(*stack).as!size_t];
                break;
            case Dynamic.Type.arr:
                *stack = f.arr[(*stack).as!size_t];
                break;
            default:
                throw new Exception("error: not a pro, fun, tab, or arr: " ~ f.to!string);
            }
            break;
        case Opcode.scall:
            ushort constIndex = instrs.eat!ushort(index);
            Dynamic f = func.constants[constIndex];
            ushort count = instrs.eat!ushort(index);
            stack -= count;
            stack += 1;
            Dynamic res = void;
            switch (f.type)
            {
            case Dynamic.Type.fun:
                res = f.fun.fun.value(stack[0 .. 0 + count]);
                break;
            case Dynamic.Type.pro:
                res = run(f.fun.pro, stack[0 .. 0 + count]);
                break;
            case Dynamic.Type.tab:
                res = f.tab()(stack[0 .. 0 + count]);
                break;
            case Dynamic.Type.tup:
                res = f.arr[(*stack).as!size_t];
                break;
            case Dynamic.Type.arr:
                res = f.arr[(*stack).as!size_t];
                break;
            default:
                throw new Exception("error: not a pro, fun, tab, or arr: " ~ f.to!string);
            }
            *stack = res;
            break;
        case Opcode.oplt:
            stack -= 1;
            *stack = dynamic(*stack < *(stack + 1));
            break;
        case Opcode.opgt:
            stack -= 1;
            *stack = dynamic(*stack > *(stack + 1));
            break;
        case Opcode.oplte:
            stack -= 1;
            *stack = dynamic(*stack <= *(stack + 1));
            break;
        case Opcode.opgte:
            stack -= 1;
            *stack = dynamic(*stack >= *(stack + 1));
            break;
        case Opcode.opeq:
            stack -= 1;
            *stack = dynamic(*stack == *(stack + 1));
            break;
        case Opcode.opneq:
            stack -= 1;
            *stack = dynamic(*stack != *(stack + 1));
            break;
        case Opcode.tuple:
            ushort got = instrs.eat!ushort(index);
            stack -= got;
            *(++stack) = Dynamic.tuple(stack[0 .. got].dup);
            break;
        case Opcode.array:
            ushort got = instrs.eat!ushort(index);
            stack -= got;
            *(++stack ) = stack[0 .. got].dup.dynamic;
            break;
        case Opcode.table:
            ushort count = instrs.eat!ushort(index);
            Mapping table = emptyMapping;
            foreach (i; 0 .. count)
            {
                table[*(stack-1)] = *stack;
                stack -= 2;
            }
            *(++stack) = dynamic(table);
            break;
        case Opcode.index:
            Dynamic ind = *stack;
            stack--;
            Dynamic arr = *stack;
            switch (arr.type)
            {
            case Dynamic.Type.tup:
                *stack = arr.arr[ind.as!size_t];
                break;
            case Dynamic.Type.arr:
                *stack = arr.arr[ind.as!size_t];
                break;
            case Dynamic.Type.tab:
                *stack = (arr.tab)[ind];
                break;
            default:
                throw new Exception("error: cannot index a " ~ arr.type.to!string);
            }
            break;
        case Opcode.opneg:
            *stack = -(*stack);
            break;
        case Opcode.opcat:
            stack--;
            *stack = *stack ~ *(stack+1);
            break;
        case Opcode.opadd:
            stack--;
            *stack = *stack + *(stack+1);
            break;
        case Opcode.opsub:
            stack--;
            *stack = *stack - *(stack+1);
            break;
        case Opcode.opmul:
            stack--;
            *stack = *stack * *(stack+1);
            break;
        case Opcode.opdiv:
            stack--;
            *stack = *stack / *(stack+1);
            break;
        case Opcode.opmod:
            stack--;
            *stack = *stack % *(stack+1);
            break;
        case Opcode.load:
            *(++stack) = locals[instrs.eat!ushort(index)];
            break;
        case Opcode.loadc:
            ushort capIndex = instrs.eat!ushort(index);
            *(++stack) = *func.captured[capIndex];
            break;
        case Opcode.store:
            locals[instrs.eat!ushort(index)] = *stack;
            break;
        case Opcode.istore:
            Dynamic val = *stack;
            stack--;
            Dynamic ind = *stack;
            stack--;
            Dynamic arr = *stack;
            switch (arr.type)
            {
            case Dynamic.Type.tup:
                arr.arr[ind.as!size_t] = val;
                break;
            case Dynamic.Type.arr:
                arr.arr[ind.as!size_t] = val;
                break;
            case Dynamic.Type.tab:
                arr.tab.set(ind, val);
                break;
            default:
                throw new Exception("error: cannot store at index on a " ~ arr.type.to!string);
            }
            break;
        case Opcode.cstore:
            Dynamic rhs = *stack;
            ushort local = instrs.eat!ushort(index);
            *func.captured[local] = rhs; 
            break;
        case Opcode.retval:
            Dynamic v = *(stack--);
            static foreach (callback; rest)
            {
                static if (is(typeof(callback) == LocalFormback))
                {
                    {
                        callback(index, locals[0..func.stab.length]);
                    }
                }
            }
            return v;
        case Opcode.retnone:
            static foreach (callback; rest)
            {
                static if (is(typeof(callback) == LocalFormback))
                {
                    {
                        callback(index, locals[0..func.stab.length]);
                    }
                }
            }
            return Dynamic.nil;
        case Opcode.iftrue:
            Dynamic val = *(stack--);
            ushort id = instrs.eat!ushort(index);
            if (val.type != Dynamic.Type.nil && val.log)
            {
                index = id;
            }
            break;
        case Opcode.branch:
            Dynamic val = *(stack--);
            ushort tb = instrs.eat!ushort(index);
            if (val.type != Dynamic.Type.nil && val.log)
            {
                index = tb;
            }
            else {
                index = instrs.peek!ushort(index);
            }
            break;
        case Opcode.iffalse:
            Dynamic val = *(stack--);
            ushort id = instrs.eat!ushort(index);
            if (val.type == Dynamic.Type.nil || !val.log)
            {
                index = id;
            }
            break;
        case Opcode.jump:
            ushort id = instrs.eat!ushort(index);
            index = id;
            break;
        case Opcode.argno:
            *(++stack) = args[instrs.eat!ushort(index)];
            break;
        case Opcode.args:
            *(++stack) = dynamic(args);
            break;
        case Opcode.inspect:
            assert(false);
        }
    }
    assert(0);
}
