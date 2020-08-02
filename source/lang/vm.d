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
            locals[cast(size_t) to.num] = from;
        }
        else
        {
            mixin(" locals[cast(size_t) to.num]" ~ op ~ "from;");
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
                arr.arr[to.arr[1].num.to!size_t] = from;
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
                mixin("arr.arr[to.arr[1].num.to!size_t]" ~ op ~ " from;");
                break;
            case Dynamic.Type.tab:
                mixin("arr.tab[to.arr[1]]" ~ op ~ " from;");
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
            tab[to] = mixin("tab[to]" ~ op ~ " from");
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

__gshared size_t calldepth;
__gshared Dynamic[][] stacks;
__gshared Dynamic[][] localss;
__gshared size_t[] indexs;
__gshared Function[] funcs;
__gshared size_t[] depths;
__gshared size_t exiton;

ref Dynamic[] stack()
{
    return stacks[calldepth - 1];
}

ref Dynamic[] locals()
{
    return localss[calldepth - 1];
}

ref size_t index()
{
    return indexs[calldepth - 1];
}

ref size_t depth()
{
    return depths[calldepth - 1];
}

Function func()
{
    return funcs[calldepth - 1];
}

void enterScope(Function afunc, Dynamic[] args)
{
    if (calldepth + 4 > funcs.length)
    {
        funcs.length = funcs.length * 2 + 5;
        stacks.length = stacks.length * 2 + 5;
        localss.length = localss.length * 2 + 5;
        indexs.length = indexs.length * 2 + 5;
        depths.length = depths.length * 2 + 5;
    }
    funcs[calldepth] = afunc;
    // stacks[calldepth] = new Dynamic[afunc.stackSize];
    // localss[calldepth] = new Dynamic[afunc.stab.byPlace.length + 1];

    Dynamic* ptr = cast(Dynamic*) GC.calloc(
            (afunc.stackSize + afunc.stab.byPlace.length + 1) * Dynamic.sizeof);
    stacks[calldepth] = ptr[0 .. afunc.stackSize];
    localss[calldepth] = ptr[afunc.stackSize .. afunc.stackSize + afunc.stab.byPlace.length + 1];
    // stacks[calldepth] = new Dynamic[2 ^^ 16];
    // Dynamic* ptr = cast(Dynamic*) GC.malloc((afunc.stab.byPlace.length + 1) * Dynamic.sizeof);
    // localss[calldepth] = ptr[0 .. afunc.stab.byPlace.length + 1];
    indexs[calldepth] = 0;
    depths[calldepth] = 0;
    calldepth += 1;

    foreach (i, v; args)
    {
        locals[i] = v;
    }
    // writeln("byPlace: ", func.captab.byPlace);
    // writeln("function: ", cast(void*) func);
    // writeln("captured: ", func.captured.map!(x => *x));
    // writeln("constants: ", func.constants);
    // writeln("funcs: ", func.funcs);
    // writeln("locals: ", locals);
    // writeln;
}

void exitScope()
{
    calldepth--;
    // writeln("exit");
    // funcs.length--;
    // stacka.length--;
    // localsa.length--;
    // indexs.length--;
    // deptha.length--;
}

JSONValue[] vmRecord;

Dynamic run1(bool saveLocals = false, bool hasScope = true, bool saving = true, bool savable = true)(
        Function afunc, Dynamic[] args)
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
    size_t exiton = calldepth;
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
        // writeln(stack);
        static if (saving)
        {
            File file = File("world/vm/" ~ vmRecord.length.to!string ~ ".json", "w");
            vmRecord ~= saveState;
            file.write(vmRecord[$ - 1].toString);
        }
        // writeln("stacks[", calldepth, "]: ", stack[0 .. depth], "\n", "locals: ", locals, "\n");
        // writeln(cur);
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
            if (built.env)
            {
                built.captured ~= &locals[$ - 1];
            }
            stack[depth++] = dynamic(built);
            break;
        case Opcode.bind:
            depth--;
            // (obj.tab)[stack[depth]].fun.pro.self = [obj];
            assert(stack[depth - 1].tab[stack[depth]].type == Dynamic.Type.pro);
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
            case Dynamic.Type.pro:
                enterScope(f.fun.pro, // f.fun.pro.self ~ stack[depth .. depth + cur.value]);
                        stack[depth .. depth + cur.value]);
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
            case Dynamic.Type.pro:
                // enterScope(f.fun.pro, f.fun.pro.self ~ cargs);
                enterScope(f.fun.pro, cargs);
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
                stack[depth - 1] = (arr.arr)[stack[depth].num.to!size_t];
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
            stack[depth - 1] = stack[depth - 1] + stack[depth];
            break;
        case Opcode.opsub:
            depth--;
            stack[depth - 1] = stack[depth - 1] - stack[depth];
            break;
        case Opcode.opmul:
            depth--;
            stack[depth - 1] = stack[depth - 1] * stack[depth];
            break;
        case Opcode.opdiv:
            depth--;
            stack[depth - 1] = stack[depth - 1] / stack[depth];
            break;
        case Opcode.opmod:
            depth--;
            stack[depth - 1] = stack[depth - 1] % stack[depth];
            break;
        case Opcode.load: // writeln(locals, "[", cur.value,"]");
            stack[depth++] = locals[cur.value];
            break;
        case Opcode.loadc:
            stack[depth++] = *func.captured[cur.value];
            break;
        case Opcode.loadenv:
            stack[depth++] = *func.captured[$ - 1];
            break;
        case Opcode.loaduse:
            stack[depth++] = locals[$ - 1];
            break;
        case Opcode.use:
            stack[depth - 1] = locals[$ - 1].tab[dynamic(stack[depth - 1].str)];
            break;
        case Opcode.store:
            locals[cur.value] = stack[depth - 1];
            break;
        case Opcode.istore:
            switch (stack[depth - 2].type)
            {
            case Dynamic.Type.arr:
                stack[depth - 2].arr[stack[depth - 1].num.to!size_t] = stack[depth - 3];
                break;
            case Dynamic.Type.tab:
                stack[depth - 2].tab[stack[depth - 1]] = stack[depth - 3];
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
        case Opcode.qstore:
            depth -= 1;
            locals[$ - 1].tab[dynamic(stack[depth].str)] = stack[depth - 1];
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
                        mixin("arr.arr[stack[depth-1].num.to!size_t]" ~ opm[0] ~ " stack[depth-3];");
                        break switchOpi;
                    case Dynamic.Type.tab:
                        mixin("arr.tab[stack[depth-1]]" ~ opm[0] ~ " stack[depth-3];");
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
        case Opcode.opqstore:
            depth -= 1;
        switchOpq:
            switch (func.instrs[++index].value)
            {
            default:
                assert(0);
                static foreach (opm; mutMap)
                {
            case opm[1].to!AssignOp:
                    mixin(
                            "locals[$ - 1].tab[dynamic(stack[depth].str)]"
                            ~ opm[0] ~ "stack[depth - 1];");
                    break switchOpq;
                }
            }
            break;
        case Opcode.retval:
            Dynamic v = stack[--depth];
            if (calldepth == exiton)
            {
                return v;
            }
            exitScope;
            stack[depth - 1] = v;
            break;
        case Opcode.retnone:
            if (calldepth == exiton)
            {
                return Dynamic.nil;
            }
            exitScope;
            stack[depth - 1] = Dynamic.nil;
            break;
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
        case Opcode.douse:
            locals ~= stack[--depth];
            break;
        case Opcode.unuse:
            stack[depth++] = locals[$ - 1];
            locals.length--;
            break;
        }
        index++;
    }
    assert(0);
}
