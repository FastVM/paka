module purr.ir.repr;

import purr.bytecode;

class Block
{
    Instruction[] instrs;
    Branch exit;
}

class Instruction
{
    void emit(Function func)
    {
        assert(false);
    }
}

class Branch : Instruction
{
    void emit(Function func)
    {
        assert(false);
    }
}

class Call : Instruction
{
    void emit(Function func)
    {

    }
}

class Push : Instruction
{
    void emit(Function func)
    {

    }
}

class Pop : Instruction
{
    void emit(Function func)
    {

    }
}