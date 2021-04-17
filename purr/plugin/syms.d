module purr.plugin.syms;
import purr.dynamic;
import purr.io;

__gshared Dynamic function(Args)[string] syms;

Dynamic function(Args) getNative(string mangled)
{
    Dynamic function(Args) ret;
    synchronized
    {
        ret = syms[mangled];
    }
    return ret;
}