module lang.bc.compiler;

import std.conv;
import std.stdio;
import lang.dynamic;
import lang.bytecode;
import lang.bc.iterator;

class OpcodeCompiler : OpcodeIterator
{
    string tccCode;
    string dynamicStrs;
    size_t strc;
    size_t depth;
    void put(T...)(T args)
    {
        foreach (i; args)
        {
            tccCode ~= i.to!string;
        }
    }

    void newline()
    {
        put("\n");
        foreach (i; 0..depth)
        {
            put("    ");
        }
    }

    this()
    {
    }

    string constDynamic(Dynamic value)
    {
        switch (value.type)
        {
        default:
            assert(0);
        case Dynamic.Type.nil:
            return "dynamic_nil";
        case Dynamic.Type.log:
            return value.log ? "dynamic_true" : "dynamic_false";
        case Dynamic.Type.sml:
            return "dynamic_float_cons(" ~ value.as!double
                .to!string ~ ")";
        case Dynamic.Type.str:
            scope(exit)
            {
                strc++;
            }
            dynamicStrs ~= "dynamic_t dynamic_str_" ~ strc.to!string ~ " = dynamic_str_cons(" ~ value.str ~ ");\n";
            return "dynamic_str_" ~ strc.to!string;
        }
    }

override:

    void got(Opcode op)
    {
    }

    void enter(Function func)
    {
        put("dynamic_t stack[", func.stackSize, "];");
        newline;
        put("{");
        depth++;
    }

    void exit(Function func)
    {
        depth--;
        newline;
        put("}");
        writeln(dynamicStrs);
        writeln(tccCode);
    }

    void nop()
    {
    }

    void push(ushort constIndex)
    {
        newline;
        put("stack[", func.stackAt[bytepos], "] = ", constDynamic(func.constants[constIndex]), ";");
    }

    void pop()
    {
    }

    void sub(ushort funcIndex)
    {
    }

    void call(ushort argCount)
    {
    }

    void upcall()
    {
    }

    void opgt()
    {
    }

    void oplt()
    {
    }

    void opgte()
    {
    }

    void oplte()
    {
    }

    void opeq()
    {
    }

    void opneq()
    {
    }

    void array()
    {
    }

    void unpack()
    {
    }

    void table()
    {
    }

    void index()
    {
    }

    void opneg()
    {
    }

    void opadd()
    {
    }

    void opsub()
    {
    }

    void opmul()
    {
    }

    void opdiv()
    {
    }

    void opmod()
    {
    }

    void load(ushort localIndex)
    {
    }

    void loadc(ushort captureIndex)
    {
    }

    void store(ushort localIndex)
    {
    }

    void istore()
    {
    }

    void opstore(ushort localIndex, ushort operation)
    {
    }

    void opistore(ushort operation)
    {
    }

    void retval()
    {
    }

    void retnone()
    {
    }

    void iftrue(ushort jumpIndex)
    {
    }

    void iffalse(ushort jumpIndex)
    {
    }

    void jump(ushort jumpIndex)
    {
    }

    void argno(ushort argIndex)
    {
    }

    void args()
    {
    }
}
