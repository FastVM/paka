module lang.vm;

import std.stdio;
import std.range;
import std.conv;
import std.algorithm;
import std.json;
import core.memory;
import core.stdc.stdlib;
import lang.serial;
import lang.dynamic;
import lang.bytecode;

enum string[2][] cmpMap()
{
    return [["oplt", "<"], ["opgt", ">"], ["oplte", "<="], ["opgte", ">="]];
}

enum string[2][] mutMap()
{
    return [["+=", "add"], ["-=", "sub"], ["*=", "mul"], ["/=", "div"], ["%=", "mod"]];
}

Dynamic[] glocals = null;

void store(string op = "=")(Dynamic[] locals, Dynamic to, Dynamic from)
{
    if (to.type == Dynamic.Type.num)
    {
        static if (op == "=")
        {
            mixin("locals[cast(size_t) to.value.num]" ~ op ~ "from;");
        }
        else
        {
            mixin("locals[cast(size_t) to.value.num].value.num" ~ op ~ "from.value.num;");
        }
    }
    else if (to.type == Dynamic.Type.dat)
    {
        Dynamic arr = (*to.value.arr)[0];
        static if (op == "=")
        {
            switch (arr.type)
            {
            case Dynamic.Type.arr:
                (*arr.value.arr)[(*to.value.arr)[1].value.num.to!size_t] = from;
                break;
            case Dynamic.Type.tab:
                (*arr.value.tab)[(*to.value.arr)[1]] = from;
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
                mixin(
                        "(*arr.value.arr)[(*to.value.arr)[1].value.num.to!size_t].value.num "
                        ~ op ~ " from.value.num;");
                break;
            case Dynamic.Type.tab:
                mixin("(*arr.value.tab)[(*to.value.arr)[1]].value.num " ~ op ~ " from.value.num;");
                break;
            default:
                throw new Exception("error: cannot store at index");
            }
        }
    }
    else
    {
        assert(to.type == from.type);
        if (to.type == Dynamic.Type.arr)
        {
            Dynamic[] arr = *from.value.arr;
            size_t index = 0;
            outwhile: while (index < to.value.arr.length)
            {
                Dynamic nto = (*to.value.arr)[index];
                if (nto.type == Dynamic.Type.pac)
                {
                    index++;
                    size_t alen = from.value.arr.length - to.value.arr.length;
                    locals.store((*to.value.arr)[index], dynamic(arr[index - 1 .. index + alen + 1]));
                    index++;
                    while (index < to.value.arr.length)
                    {
                        locals.store((*to.value.arr)[index], arr[index + alen]);
                        index++;
                    }
                    break outwhile;
                }
                else
                {
                    locals.store(nto, arr[index]);
                }
                index++;
            }
        }
        else if (to.type == Dynamic.Type.tab)
        {
            foreach (v; to.value.tab.byKeyValue)
            {
                locals.store(v.value, (*from.value.tab)[v.key]);
            }
        }
        else
        {
            assert(0);
        }
    }
}

Dynamic[][] stacka;
Dynamic[][] localsa;
size_t[] indexa;
size_t[] deptha;
Function[] funca;

ref Dynamic[] stack()
{
    return stacka[$ - 1];
}

ref Dynamic[] locals()
{
    return localsa[$ - 1];
}

ref size_t index()
{
    return indexa[$ - 1];
}

ref size_t depth()
{
    return deptha[$ - 1];
}

Function func()
{
    return funca[$ - 1];
}

void enterScope(Function afunc, Dynamic[] args)
{
    funca ~= afunc;
    stacka ~= new Dynamic[func.stackSize];
    localsa ~= new Dynamic[func.stab.byPlace.length];
    indexa ~= 0;
    deptha ~= 0;
    foreach (i, v; args)
    {
        locals[i] = v;
    }
}

void exitScope()
{
    funca.length--;
    stacka.length--;
    localsa.length--;
    indexa.length--;
    deptha.length--;
}

JSONValue[] vmRecord;

Dynamic run(bool saveLocals = false, bool hasScope = true)(Function afunc, Dynamic[] args)
{
    static if (hasScope)
    {
        if (afunc !is null)
        {
            afunc.enterScope(args);
        }
        scope (exit)
        {
            if (afunc !is null)
            {
                exitScope;
            }
        }
    }
    size_t exiton = funca.length;
    static if (saveLocals)
    {
        scope (exit)
        {
            glocals = locals[0 .. func.stab.byPlace.length].dup;
        }
    }
    vmLoop: while (true)
    {
        Instr cur = func.instrs[index];
        // vmRecord ~= saveState;
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
            foreach (i, v; built.capture)
            {
                Function.Capture cap = built.capture[i];
                if (cap.is2)
                {
                    built.captured ~= func.captured[cap.from];
                }
                else
                {
                    built.captured ~= &locals[cap.from];
                }
            }
            stack[depth++] = dynamic(built);
            break;
        case Opcode.bind:
            depth--;
            Dynamic obj = stack[depth - 1];
            (*obj.value.tab)[stack[depth]].value.fun.pro.self = [obj];
            break;
        case Opcode.call:
            depth -= cur.value;
            Dynamic f = stack[depth - 1];
            switch (f.type)
            {
            case Dynamic.Type.fun:
                stack[depth - 1] = f.value.fun.fun(stack[depth .. depth + cur.value]);
                break;
            case Dynamic.Type.pro:
                enterScope(f.value.fun.pro,
                        f.value.fun.pro.self ~ stack[depth .. depth + cur.value]);
                continue vmLoop;
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
                    cargs ~= *stack[i].value.arr;
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
                result = f.value.fun.fun(cargs);
                break;
            case Dynamic.Type.pro:
                enterScope(f.value.fun.pro, f.value.fun.pro.self ~ cargs);
                continue vmLoop;
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
                    arr ~= *stack[i].value.arr;
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
            depth --;
            while (stack[depth].type != Dynamic.Type.end)
            {
                depth--;
            }
            stack[depth] = dynamic(stack[depth + 1 .. end].dup);
            depth++;
            break;
        case Opcode.unpack:
            stack[depth] = dynamic(Dynamic.Type.pac);
            depth++;
            break;
        case Opcode.table:
            depth -= cur.value;
            Dynamic[Dynamic] table;
            size_t place = depth;
            size_t end = place + cur.value;
            while (place < end)
            {
                table[stack[place]] = stack[place + 1];
                place += 2;
            }
            stack[depth] = dynamic(table);
            depth++;
            break;
        case Opcode.index:
            depth--;
            Dynamic arr = stack[depth - 1];
            switch (arr.type)
            {
            case Dynamic.Type.arr:
                stack[depth - 1] = (*arr.value.arr)[stack[depth].value.num.to!size_t];
                break;
            case Dynamic.Type.tab:
                stack[depth - 1] = (*arr.value.tab)[stack[depth]];
                break;
            default:
                throw new Exception("error: cannot store at index");
            }
            break;
        case Opcode.opneg:
            stack[depth - 1].value.num = -stack[depth - 1].value.num;
            break;
        case Opcode.opadd:
            depth--;
            stack[depth - 1].value.num += stack[depth].value.num;
            break;
        case Opcode.opsub:
            depth--;
            stack[depth - 1].value.num -= stack[depth].value.num;
            break;
        case Opcode.opmul:
            depth--;
            stack[depth - 1].value.num *= stack[depth].value.num;
            break;
        case Opcode.opdiv:
            depth--;
            stack[depth - 1].value.num /= stack[depth].value.num;
            break;
        case Opcode.opmod:
            depth--;
            stack[depth - 1].value.num %= stack[depth].value.num;
            break;
        case Opcode.load:
            stack[depth++] = locals[cur.value];
            break;
        case Opcode.loadc:
            stack[depth++] = *func.captured[cur.value];
            break;
        case Opcode.store:
            locals[cur.value] = stack[depth - 1];
            break;
        case Opcode.pstore:
            locals[cur.value] = stack[--depth];
            break;
        case Opcode.istore:
            switch (stack[depth - 2].type)
            {
            case Dynamic.Type.arr:
                (*stack[depth - 2].value.arr)[stack[depth - 1].value.num.to!size_t] = stack[depth
                    - 3];
                break;
            case Dynamic.Type.tab:
                (*stack[depth - 2].value.tab)[stack[depth - 1]] = stack[depth - 3];
                break;
            default:
                throw new Exception("error: cannot store at index");
            }
            depth -= 3;
            break;
        case Opcode.tstore:
            depth -= 2;
            locals.store(stack[depth + 1], stack[depth]);
            break;
        case Opcode.oppstore:
            index++;
        switchOpp:
            switch (func.instrs[index].value)
            {
            default:
                assert(0);
                static foreach (opm; mutMap)
                {
            case opm[1].to!AssignOp:
                    mixin("locals[cur.value].value.num " ~ opm[0] ~ " stack[--depth].value.num;");
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
                        mixin("(*arr.value.arr)[stack[depth-1].value.num.to!size_t].value.num "
                                ~ opm[0] ~ " stack[depth-3].value.num;");
                        break switchOpi;
                    case Dynamic.Type.tab:
                        mixin(
                                "(*arr.value.tab)[stack[depth-1]].value.num "
                                ~ opm[0] ~ " stack[depth-3].value.num;");
                        break switchOpi;
                    default:
                        throw new Exception("error: cannot store at index");
                    }
                }
            }
            depth -= 3;
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
            break;
        case Opcode.retval:
            Dynamic v = stack[--depth];
            if (funca.length == exiton)
            {
                return v;
            }
            exitScope;
            stack[depth - 1] = v;
            break;
        case Opcode.retnone:
            if (funca.length == exiton)
            {
                return nil;
            }
            exitScope;
            stack[depth - 1] = nil;
            break;
        case Opcode.iftrue:
            Dynamic val = stack[--depth];
            if (val.type != Dynamic.Type.nil && (val.type != Dynamic.Type.log || val.value.log))
            {
                index = cur.value;
            }
            break;
        case Opcode.iffalse:
            Dynamic val = stack[--depth];
            if (val.type == Dynamic.Type.nil || (val.type == Dynamic.Type.log && !val.value.log))
            {
                index = cur.value;
            }
            break;
        case Opcode.jump:
            index = cur.value;
            break;
        }
        index++;
    }
    assert(0);
}
