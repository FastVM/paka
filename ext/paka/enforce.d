module paka.enforce;

import paka.value;
import purr.dynamic;
import purr.srcloc;
import purr.vm;
import purr.dynamic;
import purr.bytecode;
import std.algorithm;
import std.functional;
import purr.io;
import std.array;
import std.conv;

string getSrcValue(Span span)
{
    assert(span.first.line == span.last.line);
    string[] strs = span.first.src.splitter("\n").array;
    return strs[span.first.line - 1][span.first.column - 1 .. span.last.column - 1];
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
        ubyte[] bytes = func.instrs[lpos .. info.index - Opcode.sizeof];
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
            values ~= new Value(stack[$ - 1]);
            break;
        case Opcode.pop:
            values.length--;
            break;
        case Opcode.sub:
            break;
        case Opcode.call:
            ushort got = eat!ushort;
            Value call = new Call(values[$-got-1], values[$-got..$], stack[$ - 1]);
            values.length -= got;
            values[$-1] = call;
            break;
        case Opcode.oplt:
            Value rhs = values[$ - 1];
            Value lhs = values[$ - 2];
            values.length -= 2;
            values ~= new Binary!"<"(lhs, rhs, stack[$ - 1]);
            break;
        case Opcode.opgt:
            Value lhs = values[$ - 2];
            Value rhs = values[$ - 1];
            values.length -= 2;
            values ~= new Binary!">"(lhs, rhs, stack[$ - 1]);
            break;
        case Opcode.oplte:
            Value rhs = values[$ - 1];
            Value lhs = values[$ - 2];
            values.length -= 2;
            values ~= new Binary!"<="(lhs, rhs, stack[$ - 1]);
            break;
        case Opcode.opgte:
            Value rhs = values[$ - 1];
            Value lhs = values[$ - 2];
            values.length -= 2;
            values ~= new Binary!">="(lhs, rhs, stack[$ - 1]);
            break;
        case Opcode.opeq:
            Value rhs = values[$ - 1];
            Value lhs = values[$ - 2];
            values.length -= 2;
            values ~= new Binary!"=="(lhs, rhs, stack[$ - 1]);
            break;
        case Opcode.opneq:
            Value rhs = values[$ - 1];
            Value lhs = values[$ - 2];
            values.length -= 2;
            values ~= new Binary!"!="(lhs, rhs, stack[$ - 1]);
            break;
        case Opcode.array:
            ushort got = eat!ushort;
            values.length -= got;
            values ~= new Value(stack[$ - 1]);
            break;
        case Opcode.table:
            ushort got = eat!ushort;
            values.length -= got;
            values ~= new Value(stack[$ - 1]);
            break;
        case Opcode.index:
            Value rhs = values[$ - 1];
            Value lhs = values[$ - 2];
            values.length -= 2;
            values ~= new Index(lhs, rhs, stack[$ - 1]);
            break;
        case Opcode.opneg:
            break;
        case Opcode.opcat:
            Value rhs = values[$ - 1];
            Value lhs = values[$ - 2];
            values.length -= 2;
            values ~= new Binary!"~"(lhs, rhs, stack[$ - 1]);
            break;
        case Opcode.opadd:
            Value rhs = values[$ - 1];
            Value lhs = values[$ - 2];
            values.length -= 2;
            values ~= new Binary!"+"(lhs, rhs, stack[$ - 1]);
            break;
        case Opcode.opsub:
            Value rhs = values[$ - 1];
            Value lhs = values[$ - 2];
            values.length -= 2;
            values ~= new Binary!"-"(lhs, rhs, stack[$ - 1]);
            break;
        case Opcode.opmul:
            Value rhs = values[$ - 1];
            Value lhs = values[$ - 2];
            values.length -= 2;
            values ~= new Binary!"*"(lhs, rhs, stack[$ - 1]);
            break;
        case Opcode.opdiv:
            Value rhs = values[$ - 1];
            Value lhs = values[$ - 2];
            values.length -= 2;
            values ~= new Binary!"/"(lhs, rhs, stack[$ - 1]);
            break;
        case Opcode.opmod:
            Value rhs = values[$ - 1];
            Value lhs = values[$ - 2];
            values.length -= 2;
            values ~= new Binary!"%"(lhs, rhs, stack[$ - 1]);
            break;
        case Opcode.load:
            values ~= new Load(func.stab[eat!ushort], stack[$ - 1]);
            break;
        case Opcode.loadc:
            values ~= new Load(func.captab[eat!ushort], stack[$ - 1]);
            break;
        case Opcode.store:
            break;
        case Opcode.cstore:
            break;
        case Opcode.istore:
            break;
        case Opcode.opstore:
            break;
        case Opcode.opcstore:
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
