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

alias LocalCallback = void delegate(uint index, Dynamic[] locals);

enum string[2][] cmpMap()
{
    return [["oplt", "<"], ["opgt", ">"], ["oplte", "<="], ["opgte", ">="]];
}

enum string[2][] mutMap()
{
    return [["+", "add"], ["-", "sub"], ["*", "mul"], ["/", "div"], ["%", "mod"], ["~", "cat"]];
}

pragma(inline, true) T eat(T, A)(ubyte* bytes, ref A index)
{
    T ret = *cast(T*)(bytes + index);
    index += T.sizeof;
    return ret;
}

pragma(inline, true) T peek(T, A)(ubyte* bytes, A index)
{
    return *cast(T*)(bytes + index);
}

size_t depth;
pragma(inline, false) Dynamic run(T...)(Bytecode func, Dynamic[] args = null, T rest = T.init)
{
    static foreach (I; T)
    {
        static assert(is(I == LocalCallback));
    }
    Dynamic* stack = void;
    if ((func.flags & Bytecode.Flags.isLocal) || T.length != 0)
    {
        stack = cast(Dynamic*) GC.malloc((func.stackSize + func.stab.length) * Dynamic.sizeof);
    }
    else
    {
        stack = cast(Dynamic*) alloca((func.stackSize + func.stab.length) * Dynamic.sizeof);
    }
    ushort index;
    Dynamic* locals;
    version (PurrErrors)
    {
        scope (failure)
        {
            debugFrames ~= new DebugFrame(func, index, locals);
        }
    }
    scope (success)
    {
        static foreach (callbackIndex, callback; rest)
        {
            static if (is(typeof(callback) == LocalCallback))
            {
                if (callback !is null)
                {
                    callback(index, locals[0 .. func.stab.length]);
                }
            }
        }
    }
    // depth++;
    // if (depth > 100)
    // {
    //     throw new Exception("stack overflow");
    // }
    // scope(exit)
    // {
    //     depth--;
    // }
    Dynamic* rstack = stack;
    locals = stack + func.stackSize;
    ubyte* instrs = func.instrs.ptr;
redoSame:
    index = 0;
    while (true)
    {
        Opcode cur = instrs.eat!Opcode(index);
        // writeln(rstack[0..stack-rstack]);
        // writeln(cur);
        switch (cur)
        {
        default:
            assert(false, cur.to!string);
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
            Bytecode built = new Bytecode(func.funcs[instrs.eat!ushort(index)]);
            built.parent = func;
            built.captured = new Dynamic*[built.capture.length];
            foreach (i, v; built.capture)
            {
                Bytecode.Capture cap = built.capture[i];
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
            *stack = (*stack)(stack[1 .. 1 + count]);
            break;
        case Opcode.scall:
            ushort constIndex = instrs.eat!ushort(index);
            Dynamic funcToCall = func.constants[constIndex];
            ushort count = instrs.eat!ushort(index);
            stack -= count;
            stack += 1;
            *stack = funcToCall(stack[1 .. 1 + count]);
            break;
        case Opcode.tcall:
            ushort count = instrs.eat!ushort(index);
            stack -= count;
            Dynamic funcToCall = *stack;
            if (false && funcToCall.value.fun.pro == func
                    && (func.flags & Bytecode.Flags.isLocal) && T.length == 0)
            {
                args = stack[1 .. 1 + count].dup;
                stack = rstack;
                index = 0;
                break;
            }
            else
            {
                return funcToCall(stack[1 .. 1 + count]);
            }
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
            *(++stack) = stack[0 .. got].dup.dynamic;
            break;
        case Opcode.table:
            ushort count = instrs.eat!ushort(index);
            Mapping table = emptyMapping;
            foreach (i; 0 .. count)
            {
                table[*(stack - 1)] = *stack;
                stack -= 2;
            }
            *(++stack) = dynamic(table);
            break;
        case Opcode.opindex:
            Dynamic ind = *stack;
            stack--;
            Dynamic arr = *stack;
            *stack = arr[ind];
            // switch (arr.type)
            // {
            // case Dynamic.Type.tup:
            //     *stack = arr.arr[ind.as!size_t];
            //     break;
            // case Dynamic.Type.arr:
            //     *stack = arr.arr[ind.as!size_t];
            //     break;
            // case Dynamic.Type.tab:
            //     *stack = (arr.tab)[ind];
            //     break;
            // default:
            //     throw new Exception("error: cannot index a " ~ arr.type.to!string);
            // }
            break;
        case Opcode.opindexc:
            ushort constIndex = instrs.eat!ushort(index);
            Dynamic ind = func.constants[constIndex];
            Dynamic arr = *stack;
            *stack = arr[ind];
            break;
        case Opcode.gocache:
            ushort cacheNumber = instrs.peek!ushort(index);
            func.cached[cacheNumber] = new Dynamic(*stack);
            index = instrs.peek!ushort(index + 2);
            break;
        case Opcode.cbranch:
            ushort ndeps = instrs.peek!ushort(index);
            stack -= ndeps;
            stack++;
            ushort cacheNumber = instrs.peek!ushort(index + 2);
            assert(func.cacheCheck[cacheNumber].length == ndeps);
            foreach (key, value; func.cacheCheck[cacheNumber])
            {
                if (!stack[key].isSameObject(value))
                {
                    func.cached[cacheNumber] = null;
                    break;
                }
            }
            if (Dynamic* dyn = func.cached[cacheNumber])
            {
                *(stack) = *dyn;
                index = instrs.peek!ushort(index + 6);
            }
            else
            {
                func.cacheCheck[cacheNumber] = stack[0 .. ndeps].dup;
                stack--;
                index = instrs.peek!ushort(index + 4);
            }
            break;
        case Opcode.opneg:
            *stack = -(*stack);
            break;
        case Opcode.opcat:
            stack--;
            *stack = *stack ~ *(stack + 1);
            break;
        case Opcode.opadd:
            stack--;
            *stack = *stack + *(stack + 1);
            break;
        case Opcode.opinc:
            *stack = Dynamic(stack.as!double + instrs.eat!ushort(index));
            break;
        case Opcode.opsub:
            stack--;
            *stack = *stack - *(stack + 1);
            break;
        case Opcode.opdec:
            *stack = Dynamic(stack.as!double - instrs.eat!ushort(index));
            break;
        case Opcode.opmul:
            stack--;
            *stack = *stack * *(stack + 1);
            break;
        case Opcode.opdiv:
            stack--;
            *stack = *stack / *(stack + 1);
            break;
        case Opcode.opmod:
            stack--;
            *stack = *stack % *(stack + 1);
            break;
        case Opcode.load:
            *(++stack) = locals[instrs.eat!ushort(index)];
            break;
        case Opcode.loadcap:
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
            arr[ind] = val;
            // switch (arr.type)
            // {
            // case Dynamic.Type.tup:
            //     arr.arr[ind.as!size_t] = val;
            //     break;
            // case Dynamic.Type.arr:
            //     arr.arr[ind.as!size_t] = val;
            //     break;
            // case Dynamic.Type.tab:
            //     arr.tab.set(ind, val);
            //     break;
            // default:
            //     throw new Exception("error: cannot store at index on a " ~ arr.type.to!string);
            // }
            break;
        case Opcode.cstore:
            Dynamic rhs = *stack;
            ushort local = instrs.eat!ushort(index);
            *func.captured[local] = rhs;
            break;
        case Opcode.retval:
            Dynamic v = *(stack--);
            return v;
        case Opcode.retconst:
            ushort constIndex = instrs.peek!ushort(index);
            return func.constants[constIndex];
        case Opcode.retnone:
            return Dynamic.nil;
        case Opcode.iftrue:
            Dynamic val = *(stack--);
            ushort id = instrs.eat!ushort(index);
            if (val.isNil && val.log)
            {
                index = id;
            }
            break;
        case Opcode.branch:
            Dynamic val = *(stack--);
            ushort tb = instrs.eat!ushort(index);
            if (val.isTruthy)
            {
                index = tb;
            }
            else
            {
                index = instrs.peek!ushort(index);
            }
            break;
        case Opcode.iffalse:
            Dynamic val = *(stack--);
            ushort id = instrs.eat!ushort(index);
            if (!val.isTruthy)
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
        case Opcode.inspect:
            assert(false);
        }
    }
    assert(0);
}
