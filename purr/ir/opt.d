module purr.ir.opt;

import purr.io;
import std.conv;
import purr.ir.repr;

class Opt
{
    size_t optlevel = 3;
    BasicBlock[BasicBlock] done;
    
    this(size_t o = 3)
    {
        optlevel = o;
    }

    BasicBlock opt(BasicBlock bb)
    {
        if (BasicBlock* ret = bb in done)
        {
            return *ret;
        }
        BasicBlock ret = new BasicBlock(bb.name);
        done[bb] = ret;
        ret.instrs = bb.instrs;
        ret.exit = bb.exit;
        ret.counts = bb.counts;
        return ret;
    }
}
