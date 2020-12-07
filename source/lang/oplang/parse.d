module lang.oplang.parse;

import std.conv;
import std.stdio;
import lang.bytecode;

Function parse(string code)
{
    assert(0);
}

string serialize(Function func)
{
    string ret;
    size_t index = 0;
    Opcode readop()
    {
        Opcode v = cast(Opcode) func.instrs[index++];
        ret ~= v.to!string;
        ret ~= ' ';
        return v;
    }

    ushort readui()
    {
        ushort res = *cast(ushort*)(func.instrs.ptr + index);
        index += ushort.sizeof;
        return res;
    }

    while (index < func.instrs.length)
    {
        Opcode op = readop;
        final switch (op)
        {
        case Opcode.nop:
            break;
        case Opcode.push:
            break;
        case Opcode.pop:
            break;
        case Opcode.sub:
            break;
        case Opcode.bind:
            break;
        case Opcode.call:
            break;
        case Opcode.upcall:
            break;
        case Opcode.oplt:
            break;
        case Opcode.opgt:
            break;
        case Opcode.oplte:
            break;
        case Opcode.opgte:
            break;
        case Opcode.opeq:
            break;
        case Opcode.opneq:
            break;
        case Opcode.array:
            break;
        case Opcode.unpack:
            break;
        case Opcode.table:
            break;
        case Opcode.index:
            break;
        case Opcode.opneg:
            break;
        case Opcode.opadd:
            break;
        case Opcode.opsub:
            break;
        case Opcode.opmul:
            break;
        case Opcode.opdiv:
            break;
        case Opcode.opmod:
            break;
        case Opcode.load:
            break;
        case Opcode.loadc:
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
        }
        ret.length--;
        ret ~= ";\n";
    }
    return ret;
}
