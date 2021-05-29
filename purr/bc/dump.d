module purr.bc.dump;

import std.conv;
import purr.io;
import purr.bytecode;
import purr.bc.iterator;

final class OpcodePrinter : OpcodeIterator
{
    string ret;
    size_t depth = 0;

    void inline(A...)(A args)
    {
        static foreach (i, arg; args)
        {
            ret ~= arg.to!string;
        }
    }

    void line(A...)(A args)
    {
        inline(args, "\n");
    }

    void indent()
    {
        foreach (_; 0 .. depth)
        {
            ret ~= "    ";
        }
    }

override:
    void enter(Bytecode func)
    {
        if (func.stab.length != 0)
        {
            foreach (k, v; func.stab.byPlace)
            {
                indent;
                foreach (i; 0 .. func.instrs.length.to!string.length + 1)
                {
                    inline(' ');
                }
                line(".symbol offset=", k, " identifier=", v);
            }
        }
        if (func.capture.length != 0)
        {
            foreach (cap; func.capture)
            {
                indent;
                foreach (i; 0 .. func.instrs.length.to!string.length + 1)
                {
                    inline(' ');
                }
                line(".capture offset=", cap.offset, " identifier=", func.captab[cap.offset],
                        " from=", cap.from, " direct=", !cap.is2, " arg=", cap.isArg);
            }
        }
    }

    void got(Opcode op)
    {
        foreach (_; 0 .. depth)
        {
            ret ~= "    ";
        }
        string bstr = bytepos.to!string;
        foreach (i; bstr.length .. func.instrs.length.to!string.length)
        {
            inline('0');
        }
        inline(bstr);
        inline(": ");
    }

    void nop()
    {
        line("nop");
    }

    void push(ushort constIndex)
    {
        line("push num=", constIndex, " value=", func.constants[constIndex]);
    }

    void retconst(ushort constIndex)
    {
        line("retconst num=", constIndex, " value=", func.constants[constIndex]);
    }

    void pop()
    {
        line("pop");
    }

    void rec()
    {
        line("rec");
    }

    void sub(ushort funcIndex)
    {
        line("sub num=", funcIndex, " func={");
        depth++;
        walk(func.funcs[funcIndex]);
        depth--;
        indent;
        line("}");
    }

    void call(ushort argCount)
    {
        line("call argc=", argCount);
    }

    void scall(ushort constIndex, ushort argCount)
    {
        line("scall num=", constIndex, " argc=", argCount);
    }

    void tcall(ushort argCount)
    {
        line("tcall argc=", argCount);
    }

    void opgt()
    {
        line("opgt");
    }

    void oplt()
    {
        line("oplt");
    }

    void opgte()
    {
        line("opgte");
    }

    void oplte()
    {
        line("oplte");
    }

    void opeq()
    {
        line("opeq");
    }

    void opneq()
    {
        line("opneq");
    }

    void tuple(ushort argCount)
    {
        line("tuple length=", argCount);
    }

    void array(ushort argCount)
    {
        line("array length=", argCount);
    }

    void table(ushort argCount)
    {
        line("table length=", argCount);
    }

    void opindex()
    {
        line("opindex");
    }

    void opindexc(ushort constIndex)
    {
        line("opindexc at=", constIndex, " value=", func.constants[constIndex]);
    }

    void gocache(ushort base, ushort goto_)
    {
        line("gocache base=", base, " goto=", goto_);
    }

    void cbranch(ushort ndeps, ushort base, ushort ifeval, ushort ifcache)
    {
        line("cbranch ndeps=", ndeps, " base=", base, " ifeval=", ifeval, " ifcache=", ifcache);
    }

    void opneg()
    {
        line("opneg");
    }

    void opcat()
    {
        line("opcat");
    }

    void opadd()
    {
        line("opadd");
    }

    void opsub()
    {
        line("opsub");
    }

    void opinc(ushort n)
    {
        line("opinc by=", n);
    }

    void opdec(ushort n)
    {
        line("opdec by=", n);
    }

    void opmul()
    {
        line("opmul");
    }

    void opdiv()
    {
        line("opdiv");
    }

    void opmod()
    {
        line("opmod");
    }

    void load(ushort localIndex)
    {
        line("load offset=", localIndex, " identifier=", func.stab[localIndex]);
    }

    void loadcap(ushort captureIndex)
    {
        line("loadcap offset=", captureIndex, " capture=", func.captab[captureIndex]);
    }

    void store(ushort localIndex)
    {
        line("store offset=", localIndex, " identifier=", func.stab[localIndex]);
    }

    void istore()
    {
        line("istore");
    }

    void cstore(ushort captureIndex)
    {
        line("store offset=", captureIndex, " identifier=", func.captab[captureIndex]);
    }

    void retval()
    {
        line("retval");
    }

    void iftrue(ushort jumpIndex)
    {
        line("iftrue goto=", jumpIndex);
    }

    void branch(ushort iftrue, ushort iffalse)
    {
        line("branch iftrue=", iftrue, " iffalse=", iffalse);
    }

    void iffalse(ushort jumpIndex)
    {
        line("iffalse goto=", jumpIndex);
    }

    void jump(ushort jumpIndex)
    {
        line("jump goto=", jumpIndex);
    }

    void argno(ushort argIndex)
    {
        line("argno number=", argIndex);
    }

    void args()
    {
        line("args");
    }

    void inspect()
    {
        line("inspect");
    }
}