module purr.vm;

import std.stdio;
import std.range;
import std.conv;
import std.algorithm;
import std.json;
import std.traits;
import core.memory;
import core.stdc.stdlib;
import purr.srcloc;
import purr.error;
import purr.dynamic;
import purr.bytecode;
import purr.data.map;

Span[] spans;

void delegate(VMInfo info)[] inspects;

struct VMInfo
{
    Function func;
    Dynamic[] args;
    ushort index;
    Dynamic[] stack;
    Dynamic* locals;
}

alias LocalCallback = void delegate(uint index, Dynamic* stack, Dynamic[] locals);

enum string[2][] cmpMap()
{
    return [["oplt", "<"], ["opgt", ">"], ["oplte", "<="], ["opgte", ">="]];
}

enum string[2][] mutMap()
{
    return [["+", "add"], ["-", "sub"], ["*", "mul"], ["/", "div"], ["%", "mod"], ["~", "cat"]];
}

alias allocateStackAllowed = alloca;

pragma(inline, true) T eat(T)(ubyte* bytes, ref ushort index)
{
    scope (exit)
    {
        index += T.sizeof;
    }
    return *cast(T*)(bytes + index);
}

pragma(inline, true) T get(T)(ubyte* bytes, ref ushort index)
{
    return *cast(T*)(bytes + index);
}

pragma(inline, true) T get1(T)(ubyte* bytes, ref ushort index)
{
    return *cast(T*)(bytes + index - T.sizeof);
}

Dynamic run(T...)(Function func, Dynamic[] args = null, T rest = T.init)
{
    static foreach (I; T)
    {
        static assert(is(I == LocalCallback));
    }
    ushort index = 0;
    Dynamic* stack = void;
    Dynamic* locals = void;
    scope (failure)
    {
        spans ~= func.spans[index];
    }
    if (func.flags & Function.Flags.isLocal)
    {
        locals = cast(Dynamic*) GC.malloc((func.stab.length + 1) * Dynamic.sizeof);
        stack = (cast(Dynamic*) allocateStackAllowed(func.stackSize * Dynamic.sizeof));
    }
    else
    {
        Dynamic* ptr = cast(Dynamic*) allocateStackAllowed(
                (func.stackSize + 1 + func.stab.length) * Dynamic.sizeof);
        locals = ptr + func.stackSize;
        stack = ptr;
    }
    ubyte* instrs = func.instrs.ptr;
    Dynamic* lstack = stack;
    // writeln(cast(void*) func, func.captured);
    while (true)
    {
        // assert(func.stackSize >= stack-lstack, "stack overflow error");
        Opcode cur = cast(Opcode) instrs[index++];
        // writeln(locals[0..func.stab.length]);
        // writeln(lstack[0 .. stack - lstack]);
        // writeln;
        // writeln(index, ": ", cur);
        switch (cur)
        {
        default:
            assert(false);
            // throw new RuntimeException("opcode not found: " ~ cur.to!string);
        case Opcode.nop:
            break;
        case Opcode.push:
            (*(stack++)) = func.constants[instrs.eat!ushort(index)];
            break;
        case Opcode.pop:
            stack--;
            break;
        case Opcode.sub:
            Function built = new Function(func.funcs[instrs.eat!ushort(index)]);
            built.parent = func;
            built.names = null;
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
            (*(stack++)) = dynamic(built);
            break;
        case Opcode.call:
            stack -= instrs.eat!ushort(index);
            Dynamic f = (*(stack - 1));
            switch (f.type)
            {
            case Dynamic.Type.fun:
                (*(stack - 1)) = f.fun.fun.value(stack[0 .. 0 + instrs.get1!ushort(index)]);
                break;
            // case Dynamic.Type.del:
            //     (*(stack - 1)) = f.fun.del.value(stack[0 .. 0 + instrs.get1!ushort(index)]);
            //     break;
            case Dynamic.Type.pro:
                (*(stack - 1)) = run(f.fun.pro, stack[0 .. 0 + instrs.get1!ushort(index)]);
                break;
            case Dynamic.Type.tab:
                (*(stack - 1)) = f.tab()(stack[0 .. 0 + instrs.get1!ushort(index)]);
                break;
            default:
                throw new TypeException("error: not a function: " ~ f.to!string);
            }
            break;
        case Opcode.oplt:
            stack -= 1;
            (*(stack - 1)) = dynamic((*(stack - 1)) < (*stack));
            break;
        case Opcode.opgt:
            stack -= 1;
            (*(stack - 1)) = dynamic((*(stack - 1)) > (*stack));
            break;
        case Opcode.oplte:
            stack -= 1;
            (*(stack - 1)) = dynamic((*(stack - 1)) <= (*stack));
            break;
        case Opcode.opgte:
            stack -= 1;
            (*(stack - 1)) = dynamic((*(stack - 1)) >= (*stack));
            break;
        case Opcode.opeq:
            stack -= 1;
            (*(stack - 1)) = dynamic((*(stack - 1)) == (*stack));
            break;
        case Opcode.opneq:
            stack -= 1;
            (*(stack - 1)) = dynamic((*(stack - 1)) != (*stack));
            break;
        case Opcode.array:
            ushort got = instrs.eat!ushort(index);
            stack = stack - got;
            (*stack) = stack[0 .. got].dup.dynamic;
            stack++;
            break;
        case Opcode.table:
            ushort count = instrs.eat!ushort(index);
            Mapping table = emptyMapping;
            foreach (i; 0..count)
            {
                stack -= 2;
                table[*stack] = (*(stack + 1));
            }
            (*(stack++)) = dynamic(table);
            break;
        case Opcode.index:
            stack--;
            Dynamic arr = (*(stack - 1));
            switch (arr.type)
            {
            case Dynamic.Type.arr:
                (*(stack - 1)) = (arr.arr)[(*stack).as!size_t];
                break;
            case Dynamic.Type.tab:
                (*(stack - 1)) = (arr.tab)[(*stack)];
                break;
            default:
                throw new TypeException("error: cannot store at index on a " ~ arr.type.to!string);
            }
            break;
        case Opcode.opneg:
            (*(stack - 1)) = -(*(stack - 1));
            break;
        case Opcode.opcat:
            stack--;
            (*(stack - 1)) = (*(stack - 1)) ~ (*stack);
            break;
        case Opcode.opadd:
            stack--;
            (*(stack - 1)) = (*(stack - 1)) + (*stack);
            break;
        case Opcode.opsub:
            stack--;
            (*(stack - 1)) = (*(stack - 1)) - (*stack);
            break;
        case Opcode.opmul:
            stack--;
            (*(stack - 1)) = (*(stack - 1)) * (*stack);
            break;
        case Opcode.opdiv:
            stack--;
            (*(stack - 1)) = (*(stack - 1)) / (*stack);
            break;
        case Opcode.opmod:
            stack--;
            (*(stack - 1)) = (*(stack - 1)) % (*stack);
            break;
        case Opcode.load:
            (*(stack++)) = locals[instrs.eat!ushort(index)];
            break;
        case Opcode.loadc:
            (*(stack++)) = *func.captured[instrs.eat!ushort(index)];
            break;
        case Opcode.store:
            Dynamic rhs = (*(stack - 1));
            ushort local = instrs.eat!ushort(index);
            if (rhs.type == Dynamic.Type.pro)
            {
                Dynamic name = func.stab[local].dynamic;
                if (!rhs.value.fun.pro.names.canFind(name))
                {
                    rhs.value.fun.pro.names ~= name;
                }
            }
            locals[local] = rhs;
            stack--;
            break;
        case Opcode.istore:
            switch ((*(stack - 3)).type)
            {
            case Dynamic.Type.arr:
                (*(*(stack - 3)).arrPtr)[(*(stack - 2)).as!size_t] = (*(stack - 1));
                break;
            case Dynamic.Type.tab:
                if ((*(stack - 1)).type == Dynamic.Type.pro && (*(stack - 2)).type == Dynamic.Type.str)
                {
                    if (!(*(stack - 1)).value.fun.pro.names.canFind(*(stack - 2)))
                    {
                        (*(stack - 1)).value.fun.pro.names ~= (*(stack - 2)).str.dynamic;
                    }
                }
                (*(stack - 3)).tab.set((*(stack - 2)), (*(stack - 1)));
                break;
            default:
                throw new TypeException("error: cannot store at index on a " ~ (*(stack - 3))
                        .type.to!string);
            }
            stack -= 3;
            break;
        case Opcode.opstore:
            ushort val = instrs.eat!ushort(index);
        switchOpp:
            switch (instrs.eat!ushort(index))
            {
            default:
                assert(0);
                static foreach (opm; mutMap)
                {
            case opm[1].to!AssignOp:
                    mixin("locals[val] = locals[val] " ~ opm[0] ~ " (*(stack-1));");
                    break switchOpp;
                }
            }
            stack--;
            break;
        case Opcode.opistore:
        switchOpi:
            switch (instrs.eat!ushort(index))
            {
            default:
                assert(0);
                static foreach (opm; mutMap)
                {
            case opm[1].to!AssignOp:
                    Dynamic arr = (*(stack - 3));
                    switch (arr.type)
                    {
                    case Dynamic.Type.arr:
                        Array* arr2 = arr.arrPtr;
                        size_t ind = (*(stack - 2)).as!size_t;
                        mixin("(*arr2)[ind] = (*arr2)[ind] " ~ opm[0] ~ " (*(stack - 1));");
                        break switchOpi;
                    case Dynamic.Type.tab:
                        mixin(
                                "arr.tab.set((*(stack - 2)), arr.tab[(*(stack - 2))] "
                                ~ opm[0] ~ " (*(stack - 1)));");
                        break switchOpi;
                    default:
                        throw new TypeException(
                                "error: cannot store at index on a " ~ arr.type.to!string);
                    }
                }
            }
            stack -= 3;
            break;
        case Opcode.retval:
            Dynamic v = (*(--stack));
            static foreach (callback; rest)
            {
                static if (is(typeof(callback) == LocalCallback))
                {
                    {
                        Dynamic[] lo = locals[0 .. func.stab.length + 1].array;
                        callback(index, stack, lo);
                    }
                }
            }
            return v;
        case Opcode.retnone:
            static foreach (callback; rest)
            {
                static if (is(typeof(callback) == LocalCallback))
                {
                    {
                        Dynamic[] lo = locals[0 .. func.stab.length + 1].array;
                        callback(index, stack, lo);
                    }
                }
            }
            return Dynamic.nil;
        case Opcode.iftrue:
            Dynamic val = (*(--stack));
            if (val.type != Dynamic.Type.nil && (val.type != Dynamic.Type.log || val.log))
            {
                ushort id = instrs.get!ushort(index);
                index = id;
            }
            else
            {
                instrs.eat!ushort(index);
            }
            break;
        case Opcode.iffalse:
            Dynamic val = (*(--stack));
            if (val.type == Dynamic.Type.nil || (val.type == Dynamic.Type.log && !val.log))
            {
                ushort id = instrs.get!ushort(index);
                index = id;
            }
            else
            {
                instrs.eat!ushort(index);
            }
            break;
        case Opcode.jump:
            ushort id = instrs.get!ushort(index);
            index = id;
            break;
        case Opcode.argno:
            (*stack) = args[instrs.eat!ushort(index)];
            stack++;
            break;
        case Opcode.args:
            (*stack) = dynamic(args);
            stack++;
            break;
        case Opcode.inspect:
            VMInfo info = VMInfo(func, args, index, lstack[0 .. stack - lstack], locals);
            foreach (ins; inspects)
            {
                ins(info);
            }
            break;
        }
    }
    assert(0);
}
