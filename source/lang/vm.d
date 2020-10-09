module lang.vm;

import std.stdio;
import std.range;
import std.conv;
import std.algorithm;
import std.json;
import std.traits;
import core.memory;
import core.stdc.stdlib;
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
    return [["+=", "add"], ["-=", "sub"], ["*=", "mul"], ["/=", "div"]]; //, ["%=", "mod"]];
}

void store(string op = "=")(Dynamic[] locals, Dynamic to, Dynamic from)
{
    if (to.type == Dynamic.Type.sml || to.type == Dynamic.Type.big)
    {
        static if (op == "=")
        {
            locals[to.as!size_t] = from;
        }
        else
        {
            mixin("locals[to.as!size_t]" ~ op ~ "from;");
        }
    }
    else if (to.type == Dynamic.Type.dat)
    {
        Dynamic arr = to.arr[0];
        static if (op == "=")
        {
            switch (arr.type)
            {
            case Dynamic.Type.arr:
                arr.arr[to.arr[1].as!size_t] = from;
                break;
            case Dynamic.Type.tab:
                arr.tab[to.arr[1]] = from;
                break;
            default:
                throw new Exception("error: cannot store at index");
            }
        }
        else
        {
            switch (arr.type)
            {
            case Dynamic.Type.arr:
                mixin("arr.arr[to.arr[1].as!size_t]" ~ op ~ "from;");
                break;
            case Dynamic.Type.tab:
                mixin("arr.tab[to.arr[1]]" ~ op ~ "from;");
                break;
            default:
                throw new Exception("error: cannot store at index");
            }
        }
    }
    else if (to.type == Dynamic.type.str)
    {
        static if (op == "=")
        {
            locals[$ - 1].tab[to] = from;
        }
        else
        {
            Table tab = locals[$ - 1].tab;
            mixin("tab[to]" ~ op ~ "from;");
        }
    }
    else
    {
        assert(to.type == from.type);
        if (to.type == Dynamic.Type.arr)
        {
            Dynamic[] arr = from.arr;
            size_t index = 0;
            outwhile: while (index < to.arr.length)
            {
                Dynamic nto = (to.arr)[index];
                if (nto.type == Dynamic.Type.pac)
                {
                    index++;
                    size_t alen = from.arr.length - to.arr.length;
                    locals.store!op((to.arr)[index], dynamic(arr[index - 1 .. index + alen + 1]));
                    index++;
                    while (index < to.arr.length)
                    {
                        locals.store!op((to.arr)[index], arr[index + alen]);
                        index++;
                    }
                    break outwhile;
                }
                else
                {
                    locals.store!op(nto, arr[index]);
                }
                index++;
            }
        }
        else if (to.type == Dynamic.Type.tab)
        {
            foreach (v; to.tab.byKeyValue)
            {
                locals.store!op(v.value, (from.tab)[v.key]);
            }
        }
        else
        {
            assert(0);
        }
    }
}

// void trace(A, B)(A a, B b, ref size_t[size_t] heat)
// {
//     if (b < a)
//     {
//         size_t index2 = a * ushort.max + b;
//         size_t* ptr = index2 in heat;
//         if (ptr is null)
//         {
//             heat[index2] = 1;
//         }
//         else
//         {
//             *ptr += 1;
//             if (*ptr == 16)
//             {
//                 writeln(index2.getPlace);
//             }
//         }
//     }
// }

// ulong[2] getPlace(size_t index)
// {
//     return [index % ushort.max, index / ushort.max];
// }

// void writeTraceLn(size_t[size_t] heat)
// {
//     foreach (kv; heat.byKeyValue)
//     {
//         ulong a = kv.key / ushort.max;
//         ulong b = kv.key % ushort.max;
//         // writeln(b, "\t..\t", a, "\t->\t", kv.value);
//     }
// }

alias allocateStackAllowed = alloca;

pragma(inline, false) Dynamic run(T...)(Function func, T argss)
{
    size_t index = 0;
    size_t depth = 0;
    size_t argi = 0;
    Dynamic[] stack = void;
    Dynamic[] locals = void;
    if (__ctfe)
    {
        stack = new Dynamic[func.stackSize];
        locals = new Dynamic[func.stab.byPlace.length + 1];
    }
    else
    {
        // Dynamic* ptr = cast(Dynamic*) GC.calloc(
        //         (func.stackSize + func.stab.byPlace.length + 1) * Dynamic.sizeof);
        // stack = ptr[0 .. func.stackSize];
        if (func.flags & Function.Flags.isLocal)
        {
            Dynamic* ptr = cast(Dynamic*) GC.malloc((func.stab.byPlace.length + 1) * Dynamic.sizeof,
                    0, typeid(Dynamic));
            stack = (cast(Dynamic*) allocateStackAllowed(func.stackSize * Dynamic.sizeof))[0
                .. func.stackSize];
            locals = ptr[0 .. func.stab.byPlace.length + 1];
        }
        else
        {
            Dynamic* ptr = cast(Dynamic*) allocateStackAllowed(
                    (func.stackSize + func.stab.byPlace.length + 1) * Dynamic.sizeof);
            stack = ptr[0 .. func.stackSize];
            locals = ptr[func.stackSize .. func.stackSize + func.stab.byPlace.length + 1];
        }
    }
    static foreach (args; argss)
    {
        static if (is(typeof(args) == Dynamic[]))
        {
            foreach (v; args)
            {
                locals[argi++] = v;
            }
        }
    }
    scope (exit)
    {
        static foreach (callback; argss)
        {
            static if (is(typeof(callback) == LocalCallback))
            {
                callback(index, depth, stack, locals);
            }
        }
    }
    Instr* instrs = func.instrs.ptr;
    // size_t[size_t] heat;
    while (true)
    {
        Instr cur = instrs[index];
        switch (cur.op)
        {
        default:
            assert(0);
        case Opcode.nop:
            break;
        case Opcode.push:
            stack[depth++] = func.constants[cur.value];
            break;
        case Opcode.pop:
            depth--;
            break;
        case Opcode.data:
            stack[depth - 1].type = Dynamic.Type.dat;
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
                stack[depth - 1] = run(f.fun.pro,
                        f.fun.pro.self, stack[depth .. depth + cur.value]);
                break;
            default:
                throw new Exception("error: not a function: " ~ f.to!string);
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
                // enterScope(f.fun.pro, f.fun.pro.self ~ cargs);
                stack[depth - 1] = run(f.fun.pro, cargs);
                break;
            default:
                throw new Exception("error: not a function: " ~ f.to!string);
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
                throw new Exception("error: cannot store at index");
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
            // depth--;
            // stack[depth - 1] %= stack[depth];
            // break;
            throw new Exception("error: cannot modulo");
        case Opcode.load:
            stack[depth++] = locals[cur.value];
            break;
        case Opcode.loadc:
            stack[depth++] = *func.captured[cur.value];
            break;
        case Opcode.store:
            locals[cur.value] = stack[depth - 1];
            break;
        case Opcode.istore:
            switch (stack[depth - 2].type)
            {
            case Dynamic.Type.arr:
                (*stack[depth - 2].arrPtr)[stack[depth - 1].as!size_t] = stack[depth - 3];
                break;
            case Dynamic.Type.tab:
                (*stack[depth - 2].tabPtr)[stack[depth - 1]] = stack[depth - 3];
                break;
            default:
                throw new Exception("error: cannot store at index");
            }
            depth -= 1;
            break;
        case Opcode.tstore:
            depth -= 2;
            locals.store(stack[depth + 1], stack[depth]);
            depth++;
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
                    Dynamic arr = stack[depth - 2];
                    switch (arr.type)
                    {
                    case Dynamic.Type.arr:
                        mixin("(*arr.arrPtr)[stack[depth-1].as!size_t]" ~ opm[0] ~ " stack[depth-3];");
                        break switchOpi;
                    case Dynamic.Type.tab:
                        mixin("(*arr.tabPtr)[stack[depth-1]]" ~ opm[0] ~ " stack[depth-3];");
                        break switchOpi;
                    default:
                        throw new Exception("error: cannot store at index");
                    }
                }
            }
            depth -= 2;
            break;
        case Opcode.optstore:
            depth -= 2;
        switchOpt:
            switch (cur.value)
            {
            default:
                assert(0);
                static foreach (opm; mutMap)
                {
            case opm[1].to!AssignOp:
                    locals.store!(opm[0])(stack[depth + 1], stack[depth]);
                    break switchOpt;
                }
            }
            depth++;
            break;
        case Opcode.retval:
            // writeTraceLn(heat);
            Dynamic v = stack[--depth];
            return v;
        case Opcode.retnone:
            // writeTraceLn(heat);
            return Dynamic.nil;
        case Opcode.iftrue:
            // trace(index, cur.value, heat);
            Dynamic val = stack[--depth];
            if (val.type != Dynamic.Type.nil && (val.type != Dynamic.Type.log || val.log))
            {
                index = cur.value;
            }
            break;
        case Opcode.iffalse:
            // trace(index, cur.value, heat);
            Dynamic val = stack[--depth];
            if (val.type == Dynamic.Type.nil || (val.type == Dynamic.Type.log && !val.log))
            {
                index = cur.value;
            }
            break;
        case Opcode.jump:
            // trace(index, cur.value, heat);
            index = cur.value;
            break;
        }
        index++;
    }
    assert(0);
}
