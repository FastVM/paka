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
import lang.data.map;
public import lang.loop;

alias LocalCallback = void delegate(Dynamic[] locals);

enum string[2][] cmpMap()
{
    return [["oplt", "<"], ["opgt", ">"], ["oplte", "<="], ["opgte", ">="]];
}

enum string[2][] mutMap()
{
    return [["+", "add"], ["-", "sub"], ["*", "mul"], ["/", "div"], ["%", "mod"]];
}

alias allocateStackAllowed = alloca;

Span[] spans;

T eat(T)(ubyte* bytes, ref ushort index)
{
    scope (exit)
    {
        index += T.sizeof;
    }
    return *cast(T*)(bytes + index);
}

T get(T)(ubyte* bytes, ref ushort index)
{
    return *cast(T*)(bytes + index);
}

T get1(T)(ubyte* bytes, ref ushort index)
{
    return *cast(T*)(bytes + index - T.sizeof);
}

void run(T...)(Cont retcont, Function func, Dynamic[] args, T rest)
{
    retcont.pushify;
    static foreach (I; T)
    {
        static assert(is(I == LocalCallback));
    }
    Dynamic* locals = cast(Dynamic*) GC.malloc(
            (func.stab.byPlace.length + 1 + args.length) * Dynamic.sizeof, 0, typeid(Dynamic));
    Dynamic* stack = 1 + (cast(Dynamic*) GC.malloc((func.stackSize + 1) * Dynamic.sizeof));
    foreach (i, v; args)
    {
        locals[i] = v;
    }
    ubyte* instrs = func.instrs.ptr;
    Cont runMore(ushort index)
    {
        ushort oi = index;
        return (Dynamic push) {
            index = oi;
            (*(stack - 1)) = push;
            while (true)
            {
                Opcode cur = cast(Opcode) instrs[index++];
                switch (cur)
                {
                default:
                    // throw new RuntimeException("opcode not found: " ~ cur.op.to!string);
                    assert(0);
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
                    (*(stack++)) = dynamic(built);
                    break;
                case Opcode.bind:
                    stack--;
                    (*(stack - 1)).tab[(*stack)].fun.pro = new Function((*(stack - 1))
                            .tab[(*stack)].fun.pro);
                    (*(stack - 1)).tab[(*stack)].fun.pro.self = [(*(stack - 1))];
                    (*(stack - 1)) = (*(stack - 1)).tab[(*stack)];
                    break;
                case Opcode.call:
                    stack -= instrs.eat!ushort(index);
                    Dynamic f = (*(stack - 1));
                    switch (f.type)
                    {
                    case Dynamic.Type.fun:
                        f.fun.fun(runMore(index).asPushable,
                                stack[0 .. 0 + instrs.get1!ushort(index)]);
                        return;
                    case Dynamic.Type.del:
                        (*f.fun.del)(runMore(index)
                                .asPushable, stack[0 .. 0 + instrs.get1!ushort(index)]);
                        return;
                    case Dynamic.Type.pro:
                        run(runMore(index).asPushable,
                                f.fun.pro, stack[0 .. 0 + instrs.get1!ushort(index)]);
                        return;
                    default:
                        throw new TypeException("error: not a function: " ~ f.to!string);
                    }
                case Opcode.upcall:
                    assert(0);
                    // Dynamic* end = stack;
                    // stack--;
                    // while ((*stack).type != Dynamic.Type.end)
                    // {
                    //     stack--;
                    // }
                    // Dynamic[] cargs;
                    // for (Dynamic* i = stack + 1; i < end; i++)
                    // {
                    //     if ((*i).type == Dynamic.Type.pac)
                    //     {
                    //         i++;
                    //         cargs ~= (*i).arr;
                    //     }
                    //     else
                    //     {
                    //         cargs ~= (*i);
                    //     }
                    // }
                    // Dynamic f = (*(stack - 1));
                    // Dynamic result = void;
                    // switch (f.type)
                    // {
                    // case Dynamic.Type.fun:
                    //     result = f.fun.fun(cargs);
                    //     break;
                    // case Dynamic.Type.del:
                    //     (*(stack - 1)) = (*f.fun.del)(cargs);
                    //     break;
                    // case Dynamic.Type.pro:
                    //     (*(stack - 1)) = run(f.fun.pro, cargs);
                    //     break;
                    // case Dynamic.Type.tab:
                    //     (*(stack - 1)) = f.value.tab(cargs);
                    //     break;
                    // default:
                    //     throw new TypeException("error: not a function: " ~ f.to!string);
                    // }
                    // (*(stack - 1)) = result;
                    // break;
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
                    Dynamic* end = stack;
                    stack--;
                    while ((*stack).type != Dynamic.Type.end)
                    {
                        stack--;
                    }
                    Dynamic[] arr;
                    for (Dynamic* i = stack + 1; i < end; i++)
                    {
                        if ((*i).type == Dynamic.Type.pac)
                        {
                            i++;
                            arr ~= (*i).arr;
                        }
                        else
                        {
                            arr ~= (*i);
                        }
                    }
                    (*stack) = dynamic(arr);
                    stack++;
                    break;
                case Opcode.unpack:
                    (*(stack++)) = dynamic(Dynamic.Type.pac);
                    break;
                case Opcode.table:
                    Dynamic* end = stack;
                    while ((*(stack - 1)).type != Dynamic.Type.end)
                    {
                        stack--;
                    }
                    Mapping table = emptyMapping;
                    for (Dynamic* i = stack; i < end; i += 2)
                    {
                        if ((*i).type == Dynamic.Type.pac)
                        {
                            foreach (key, value; (*(i + 1)).tab)
                            {
                                table[key] = value;
                            }
                        }
                        else
                        {
                            table[*i] = (*(i + 1));
                        }
                    }
                    (*(stack - 1)) = dynamic(table);
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
                        throw new TypeException(
                                "error: cannot store at index on a " ~ arr.type.to!string);
                    }
                    break;
                case Opcode.opneg:
                    (*(stack - 1)) = -(*(stack - 1));
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
                    locals[instrs.eat!ushort(index)] = (*(stack - 1));
                    stack--;
                    break;
                case Opcode.istore:
                    switch ((*(stack - 3)).type)
                    {
                    case Dynamic.Type.arr:
                        (*(*(stack - 3)).arrPtr)[(*(stack - 2)).as!size_t] = (*(stack - 1));
                        break;
                    case Dynamic.Type.tab:
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
                    ushort val = instrs.eat!ushort(index);
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
                    foreach (local; rest)
                    {
                        local(locals[0..func.stab.byPlace.length + 1 + args.length]);
                    }
                    retcont(v);
                    return;
                case Opcode.retnone:
                    foreach (local; rest)
                    {
                        local(locals[0..func.stab.byPlace.length + 1 + args.length]);
                    }
                    retcont(Dynamic.nil);
                    return;
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
                }
            }
        };
    }

    runMore(0).asPushable()(Dynamic.nil);
}
