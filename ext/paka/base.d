module paka.base;

import std.conv;
import std.stdio;
import std.functional;
import purr.base;
import purr.dynamic;
import purr.bytecode;
import purr.error;
import purr.vm;
import paka.lib.io;
import paka.lib.sys;
import paka.lib.str;
import paka.lib.arr;
import paka.lib.tab;
import paka.enforce;

/// string concatenate for format strings and unicode literals
Dynamic strconcat(Args args)
{
    string ret;
    foreach (arg; args)
    {
        if (arg.type == Dynamic.Type.str)
        {
            ret ~= arg.str;
        }
        else
        {
            ret ~= arg.to!string;
        }
    }
    return ret.dynamic;
}

/// internal map function
Dynamic syslibubothmap(Args args)
{
    Array ret;
    if (args[1].arr.length != args[2].arr.length)
    {
        throw new BoundsException("bad lengths in dotmap");
    }
    foreach (i; 0 .. args[1].arr.length)
    {
        ret ~= args[0]([args[1].arr[i], args[2].arr[i]]);
    }
    return dynamic(ret);
}

/// internal map function
Dynamic syslibulhsmap(Args args)
{
    Array ret;
    foreach (i; args[1].arr)
    {
        ret ~= args[0]([i, args[2]]);
    }
    return dynamic(ret);
}

/// internal map function
Dynamic sysliburhsmap(Args args)
{
    Array ret;
    foreach (i; args[2].arr)
    {
        ret ~= args[0]([args[1], i]);
    }
    return dynamic(ret);
}

/// internal map function
Dynamic syslibupremap(Args args)
{
    Array ret;
    foreach (i; args[1].arr)
    {
        ret ~= args[0]([i]);
    }
    return dynamic(ret);
}

bool isAfter = true;
Dynamic[] last;
size_t lpos;
Value[] values;
void assertInspects(VMInfo info)
{
    Function func = info.func;
    isAfter = !isAfter;
    Dynamic[] stack = info.stack;
    if (isAfter)
    {
        ubyte[] bytes = func.instrs[lpos..info.index-Opcode.sizeof];
        T eat(T)()
        {
            T ret = *cast(T*) bytes.ptr;
            bytes = bytes[T.sizeof .. $];
            return ret;
        }
        Opcode op = eat!Opcode;
        final switch (op)
        {
        case Opcode.nop:
            break;
        case Opcode.push:
            values ~= new Value(stack[$-1]);
            break;
        case Opcode.pop:
            values.length--;
            break;
        case Opcode.sub:
            break;
        case Opcode.bind:
            assert(0);
        case Opcode.call:
            break;
        case Opcode.upcall:
            break;
        case Opcode.oplt:
            Value rhs = values[$-1];
            Value lhs = values[$-2];
            values.length -= 2;
            values ~= new Binary!"<"(lhs, rhs, stack[$-1]);
            break;
        case Opcode.opgt:
            Value lhs = values[$-2];
            Value rhs = values[$-1];
            values.length -= 2;
            values ~= new Binary!">"(lhs, rhs, stack[$-1]);
            break;
        case Opcode.oplte:
            Value rhs = values[$-1];
            Value lhs = values[$-2];
            values.length -= 2;
            values ~= new Binary!"<="(lhs, rhs, stack[$-1]);
            break;
        case Opcode.opgte:
            Value rhs = values[$-1];
            Value lhs = values[$-2];
            values.length -= 2;
            values ~= new Binary!">="(lhs, rhs, stack[$-1]);
            break;
        case Opcode.opeq:
            Value rhs = values[$-1];
            Value lhs = values[$-2];
            values.length -= 2;
            values ~= new Binary!"=="(lhs, rhs, stack[$-1]);
            break;
        case Opcode.opneq:
            Value rhs = values[$-1];
            Value lhs = values[$-2];
            values.length -= 2;
            values ~= new Binary!"!="(lhs, rhs, stack[$-1]);
            break;
        case Opcode.array:
            ushort got = eat!ushort;
            values.length -= got;
            values ~= new Value(stack[$-1]);
            break;
        case Opcode.unpack:
            break;
        case Opcode.table:
            ushort got = eat!ushort;
            values.length -= got;
            values ~= new Value(stack[$-1]);
            break;
        case Opcode.index:
            Value rhs = values[$-1];
            Value lhs = values[$-2];
            values.length -= 2;
            values ~= new Index(lhs, rhs, stack[$-1]);
            break;
        case Opcode.opneg:
            break;
        case Opcode.opcat:
            Value rhs = values[$-1];
            Value lhs = values[$-2];
            values.length -= 2;
            values ~= new Binary!"~"(lhs, rhs, stack[$-1]);
            break;
        case Opcode.opadd:
            Value rhs = values[$-1];
            Value lhs = values[$-2];
            values.length -= 2;
            values ~= new Binary!"+"(lhs, rhs, stack[$-1]);
            break;
        case Opcode.opsub:
            Value rhs = values[$-1];
            Value lhs = values[$-2];
            values.length -= 2;
            values ~= new Binary!"-"(lhs, rhs, stack[$-1]);
            break;
        case Opcode.opmul:
            Value rhs = values[$-1];
            Value lhs = values[$-2];
            values.length -= 2;
            values ~= new Binary!"*"(lhs, rhs, stack[$-1]);
            break;
        case Opcode.opdiv:
            Value rhs = values[$-1];
            Value lhs = values[$-2];
            values.length -= 2;
            values ~= new Binary!"/"(lhs, rhs, stack[$-1]);
            break;
        case Opcode.opmod:
            Value rhs = values[$-1];
            Value lhs = values[$-2];
            values.length -= 2;
            values ~= new Binary!"%"(lhs, rhs, stack[$-1]);
            break;
        case Opcode.load:
            values ~= new Load(func.stab[eat!ushort], stack[$-1]);
            break;
        case Opcode.loadc:  
            values ~= new Load(func.captab[eat!ushort], stack[$-1]);
            break;
        case Opcode.store:
            break;
        case Opcode.istore:
            break;
        case Opcode.opstore:
            break;
        case Opcode.opistore:
            break;
        case Opcode.retval:
            break;
        case Opcode.retnone:
            break;
        case Opcode.iftrue:
            break;
        case Opcode.iffalse:
            break;
        case Opcode.jump:
            break;
        case Opcode.argno:
            break;
        case Opcode.args:
            break;
        case Opcode.inspect:
            break;
        }
    }
    else
    {
        last = info.stack.dup;
        lpos = info.index;
    }
}

string assertTrace()
{
    assert(false);
}

Dynamic pakabeginassert(Args args)
{
    inspects ~= toDelegate(&assertInspects);
    return Dynamic.nil;
}

Dynamic pakaassert(Args args)
{
    if (args[0].type == Dynamic.Type.nil || (args[0].type == Dynamic.Type.log && args[0].log == false))
    {
        throw new Exception("assert: " ~ values[0].to!string);
    }
    inspects.length--;
    return Dynamic.nil;
}

Pair[] pakaBaseLibs()
{
    Pair[] ret;
    ret ~= Pair("_both_map", &syslibubothmap);
    ret ~= Pair("_lhs_map", &syslibulhsmap);
    ret ~= Pair("_rhs_map", &sysliburhsmap);
    ret ~= Pair("_pre_map", &syslibupremap);
    ret ~= Pair("_paka_begin_assert", &pakabeginassert);
    ret ~= Pair("_paka_assert", &pakaassert);
    ret.addLib("str", libstr);
    ret.addLib("arr", libarr);
    ret.addLib("tab", libtab);
    ret.addLib("io", libio);
    ret.addLib("sys", libsys);
    return ret;
}
