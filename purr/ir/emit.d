module purr.ir.emit;

import purr.ir.repr;
import std.conv;
import std.stdio;
import std.algorithm;

class Generator
{
    BasicBlock[] emitted;

    void emit(Emitter obj)
    {
        static foreach (InstrType; InstrTypes)
        {
            if (InstrType it = cast(InstrType) obj)
            {
                emitBase(it);
                return;
            }
        }
        assert(false);
    }

    void emitBase(BasicBlock bb)
    {
        if (!emitted.canFind(bb))
        {
            emitted ~= bb;
            enter(bb);
            emitEach(bb);
            exit(bb);
        }
    }

    void emitAsFunc(BasicBlock bb)
    {
        enterAsFunc(bb);
        emitBase(bb);
        exitAsFunc(bb);
    }

    void emitEach(BasicBlock bb)
    {
        foreach (instr; bb.instrs)
        {
            emit(instr);
        }
        emit(bb.exit);
    }

    void enterAsFunc(BasicBlock block)
    {
    }
    void exitAsFunc(BasicBlock block)
    {
    }
    void enter(BasicBlock block)
    {
    }
    void exit(BasicBlock block)
    {
    }

    string repr()
    {
        assert(false);
    }

    static foreach (InstrType; InstrTypes)
    {
        void emitBase(InstrType val)
        {
            enter(val);
            emit(val);
            exit(val);
        }
        void enter(InstrType val)
        {
        }
        void emit(InstrType val)
        {
            assert(false, typeid(this).to!string ~ ".enter(" ~ InstrType.stringof ~" bb) not defined");
        }
        void exit(InstrType val)
        {
        }
    }
}
