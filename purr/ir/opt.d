module purr.ir.opt;

import std.stdio;
import std.conv;
import purr.ir.repr;

void removePop(ref Instruction[] instrs)
{
    instrs.length--;
    if (instrs[$-1].canGet!PushInstruction)
    {
        instrs.length--;
    }
    else if (instrs[$-1].canGet!LoadInstruction)
    {
        instrs.length--;
    }
    else if (instrs[$-1].canGet!ArgsInstruction)
    {
        instrs.length--;
    }
    else if (instrs[$-1].canGet!LambdaInstruction)
    {
        instrs.length--;
    }
    else if (instrs[$-1].canGet!StoreInstruction)
    {
        instrs[$-1] = new StorePopInstruction(instrs[$-1].get!StoreInstruction.var);
    }
    else if (instrs[$-1].canGet!OperatorStoreInstruction)
    {
        OperatorStoreInstruction osi = instrs[$-1].get!OperatorStoreInstruction;
        instrs[$-1] = new OperatorStorePopInstruction(osi.op, osi.var);
    }
    else
    {
        assert(false, typeid(instrs[$-1]).to!string);
    }
}

bool canRemovePopRef(ref Instruction[] instrs)
{
    if (instrs[$-1].canGet!PushInstruction)
    {
        instrs.length--;
        return true;
    }
    if (instrs[$-1].canGet!LoadInstruction)
    {
        instrs.length--;
        return true;
    }
    if (instrs[$-1].canGet!ArgsInstruction)
    {
        instrs.length--;
        return true;
    }
    if (instrs[$-1].canGet!LambdaInstruction)
    {
        instrs.length--;
        return true;
    }
    if (instrs[$-1].canGet!StoreInstruction)
    {
        instrs.length--;
        return true;
    }
    if (instrs[$-1].canGet!OperatorStoreInstruction)
    {
        instrs.length--;
        return true;
    }
    return false;
}

bool canRemovePop(Instruction[] instrs)
{
    return instrs.length >= 1 && instrs.canRemovePopRef;
}

void optimize(BasicBlock bb)
{
    Instruction[] ret;
    size_t index = 0;
    while (index < bb.instrs.length)
    {
        Instruction cur = bb.instrs[index];
        ret ~= cur;
        if (cur.canGet!PopInstruction)
        {
            if (ret[0..$-1].canRemovePop)
            {
                ret.removePop;
            }
        }
        index++;
    }
    bb.instrs = ret;
}