module purr.ir.opt;

import purr.io;
import std.conv;
import purr.ir.repr;

size_t defaultOptLevel = 2;

class Opt
{
    size_t optlevel;
    bool[BasicBlock] done;
    BasicBlock delegate(BasicBlock)[] opts;

    this(size_t o = defaultOptLevel)
    {
        optlevel = o;
        switch (o)
        {
        default:
            throw new Exception("bad opt level: " ~ o.to!string);
        case 3:
            goto case;
        case 2:
            goto case;
        case 1:
            goto case;
        case 0:
            break;
        }
    }

    void opt(BasicBlock block)
    {
        if (optlevel == 0)
        {
            return;
        }
        if (bool* res = block in done)
        {
            if (*res)
            {
                return;
            }
        }
        done[block] = true;
        foreach (ref nextBlock; block.exit.target)
        {
            opt(nextBlock);
        }
        if (GotoBranch gotoBranch = cast(GotoBranch) block.exit)
        {
            BasicBlock nextBlock = gotoBranch.target[0];
            if (nextBlock.instrs.length == 0)
            {
                block.exit = nextBlock.exit;
            }
        }
        if (block.instrs.length != 0)
        {
            if (ReturnBranch lastReturn = cast(ReturnBranch) block.exit)
            {
                if (PushInstruction lastPush = cast(PushInstruction) block.instrs[$-1])
                {
                    block.exit = new ConstReturnBranch(lastPush.value);
                    block.instrs.length--;
                }
                else if (CallInstruction lastCall = cast(CallInstruction) block.instrs[$-1])
                {
                    block.exit = new TailCallBranch(lastCall.argc);
                    block.instrs.length--;
                }
            }
        }
    }
}
