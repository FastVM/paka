module purr.bc.iterator;

import std.conv;
import purr.io;
import purr.bytecode;

class OpcodeIterator
{
    Function func;

    size_t bytepos = 0;

    this() {}
    void walk(Function funcArg)
    {
        Function last = func;
        func = funcArg;
        enter(func);
        scope(exit) {
            exit(func);
            func = last;
        }
        func = funcArg;
        size_t i = 0;
        Opcode readop()
        {
            Opcode v = cast(Opcode) func.instrs[i];
            i += 2;
            return v;
        }

        ushort readui()
        {
            ushort res = *cast(ushort*)(func.instrs.ptr + i);
            i += ushort.sizeof;
            return res;
        }

        ushort get()
        {
            scope (exit)
            {
                i += ushort.sizeof;
            }
            return *cast(ushort*)(func.instrs.ptr + i);
        }

        while (i < func.instrs.length)
        {
            bytepos = i;
            Opcode op = readop;
            got(op);
            final switch (op)
            {
            case Opcode.nop:
                nop;
                break;
            case Opcode.push:
                push(get);
                break;
            case Opcode.pop:
                pop;
                break;
            case Opcode.rec:
                rec;
                break;
            case Opcode.sub:
                sub(get);
                break;
            case Opcode.call:
                call(get);
                break;
            case Opcode.scall:
                scall(get, get);
                break;
            case Opcode.oplt:
                oplt;
                break;
            case Opcode.opgt:
                opgt;
                break;
            case Opcode.oplte:
                oplte;
                break;
            case Opcode.opgte:
                opgte;
                break;
            case Opcode.opeq:
                opeq;
                break;
            case Opcode.opneq:
                opneq;
                break;
            case Opcode.tuple:
                tuple(get);
                break;
            case Opcode.array:
                array(get);
                break;
            case Opcode.table:
                table(get);
                break;
            case Opcode.index:
                index;
                break;
            case Opcode.opneg:
                opneg;
                break;
            case Opcode.opcat:
                opcat;
                break;
            case Opcode.opadd:
                opadd;
                break;
            case Opcode.opsub:
                opsub;
                break;
            case Opcode.opmul:
                opmul;
                break;
            case Opcode.opdiv:
                opdiv;
                break;
            case Opcode.opmod:
                opmod;
                break;
            case Opcode.load:
                load(get);
                break;
            case Opcode.loadc:
                loadc(get);
                break;
            case Opcode.store:
                store(get);
                break;
            case Opcode.cstore:
                cstore(get);
                break;
            case Opcode.retval:
                retval;
                break;
            case Opcode.retnone:
                retnone;
                break;
            case Opcode.iftrue:
                iftrue(get);
                break;
            case Opcode.iffalse:
                iffalse(get);
                break;
            case Opcode.jump:
                jump(get);
                break;
            case Opcode.argno:
                argno(get);
                break;
            case Opcode.args:
                args;
                break;
            case Opcode.inspect:
                inspect;
                break;
            }
        }
    }

    void enter(Function func)
    {
    }

    void exit(Function func)
    {
    }

    void got(Opcode op)
    {
    }

    void nop()
    {
    }

    void push(ushort constIndex)
    {
    }

    void pop()
    {
    }

    void rec()
    {
    }

    void sub(ushort funcIndex)
    {
    }

    void call(ushort argCount)
    {
    }

    void scall(ushort constIndex, ushort argCount)
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

    void tuple(ushort argCount)
    {
    }

    void array(ushort argCount)
    {
    }

    void table(ushort argCount)
    {
    }

    void index()
    {
    }

    void opneg()
    {
    }

    void opcat()
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

    void cstore(ushort captureIndex)
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

    void inspect()
    {
    }
}