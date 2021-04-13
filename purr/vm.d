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
import purr.error;
import purr.dynamic;
import purr.bytecode;

version = PurrErrors;

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


pragma(inline, true) T eat(T)(ubyte* bytes, ref ushort index)
{
    T ret = *cast(T*)(bytes + (index));
    index += T.sizeof;
    return ret;
}

alias allocateStackAllowed = alloca;

pragma(inline, true) 
void freeStackAllowed(size_t size)
{
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
    version (PurrErrors)
    {
        scope (failure)
        {
            if (index < func.spans.length)
            {
                spans ~= func.spans[index];
            }
        }
    }
    size_t stackAlloc = void;
    if (func.flags & Function.Flags.isLocal)
    {
        locals = cast(Dynamic*) GC.malloc(func.stab.length * Dynamic.sizeof);
        stackAlloc = func.stackSize * Dynamic.sizeof;
        stack = (cast(Dynamic*) allocateStackAllowed(stackAlloc));
    }
    else
    {
        stackAlloc = (func.stackSize + func.stab.length) * Dynamic.sizeof;
        stack = cast(Dynamic*) allocateStackAllowed(stackAlloc);
        locals = stack + func.stackSize;
    }

    ubyte* instrs = func.instrs.ptr;
    Dynamic* lstack = stack;
    while (true)
    {
        // writeln(lstack[0..stack-lstack]);
        Opcode cur = cast(Opcode) instrs[index++];
        // writeln(index, ": ", cur);
        // writeln;
        switch (cur)
        {
        default:
            assert(false);
        case Opcode.nop:
            break;
        case Opcode.push:
            ushort constIndex = instrs.eat!ushort(index);
            (*(stack++)) = func.constants[constIndex];
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
            ushort count = instrs.eat!ushort(index);
            stack -= count;
            Dynamic f = (*(stack - 1));
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
            case Dynamic.Type.arr:
                res = f.arr[(*stack).as!size_t];
                break;
            default:
                throw new TypeException("error: not a pro, fun, tab, or arr: " ~ f.to!string);
            }
            (*(stack - 1)) = res;
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
            foreach (i; 0 .. count)
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
            ushort capIndex = instrs.eat!ushort(index);
            (*(stack++)) = *func.captured[capIndex];
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
            break;
        case Opcode.cstore:
            Dynamic rhs = (*(stack - 1));
            ushort local = instrs.eat!ushort(index);
            *func.captured[local] = rhs; 
            break;
        case Opcode.istore:
            switch ((*(stack - 3)).type)
            {
            case Dynamic.Type.arr:
                (*(*(stack - 3)).arrPtr)[(*(stack - 2)).as!size_t] = (*(stack - 1));
                break;
            case Dynamic.Type.tab:
                if ((*(stack - 1)).type == Dynamic.Type.pro && (*(stack - 2))
                        .type == Dynamic.Type.str)
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
            stack -= 2;
            break;
        case Opcode.opstore:
            ushort val = instrs.eat!ushort(index);
        switchOpstore:
            switch (instrs.eat!ushort(index))
            {
            default:
                assert(0);
                static foreach (opm; mutMap)
                {
            case opm[1].to!AssignOp:
                    mixin("locals[val] = locals[val] " ~ opm[0] ~ " (*(stack-1));");
                    (*(stack - 1)) = locals[val];
                    break switchOpstore;
                }
            }
            break;
        case Opcode.opcstore:
            ushort val = instrs.eat!ushort(index);
        switchOpcstore:
            switch (instrs.eat!ushort(index))
            {
            default:
                assert(0);
                static foreach (opm; mutMap)
                {
            case opm[1].to!AssignOp:
                    mixin("*func.captured[val] = *func.captured[val] " ~ opm[0] ~ " (*(stack-1));");
                    (*(stack - 1)) = *func.captured[val];
                    break switchOpcstore;
                }
            }
            break;
        case Opcode.opistore:
        switchOpistore:
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
                        break switchOpistore;
                    case Dynamic.Type.tab:
                        mixin(
                                "arr.tab.set((*(stack - 2)), arr.tab[(*(stack - 2))] "
                                ~ opm[0] ~ " (*(stack - 1)));");
                        break switchOpistore;
                    default:
                        throw new TypeException(
                                "error: cannot store at index on a " ~ arr.type.to!string);
                    }
                }
            }
            stack -= 2;
            break;
        case Opcode.retval:
            Dynamic v = (*(--stack));
            static foreach (callback; rest)
            {
                static if (is(typeof(callback) == LocalCallback))
                {
                    {
                        Dynamic[] lo = lstack[0 .. func.stab.length + 1].array;
                        callback(index, stack, lo);
                    }
                }
            }
            freeStackAllowed(stackAlloc);
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
            freeStackAllowed(stackAlloc);
            return Dynamic.nil;
        case Opcode.iftrue:
            Dynamic val = (*(--stack));
            ushort id = instrs.eat!ushort(index);
            if (val.type != Dynamic.Type.nil && (val.type != Dynamic.Type.log || val.log))
            {
                index = id;
            }
            break;
        case Opcode.iffalse:
            Dynamic val = (*(--stack));
            ushort id = instrs.eat!ushort(index);
            if (val.type == Dynamic.Type.nil || (val.type == Dynamic.Type.log && !val.log))
            {
                index = id;
            }
            break;
        case Opcode.jump:
            ushort id = instrs.eat!ushort(index);
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
            VMInfo info = VMInfo(func, args, index,
                    lstack[0 .. stack - lstack], locals);
            foreach (ins; inspects)
            {
                ins(info);
            }
            break;
        }
    }
    assert(0);
}
