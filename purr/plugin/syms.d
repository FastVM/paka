module purr.plugin.syms;
import purr.dynamic;

__gshared Dynamic function(Args)[string] syms;

Dynamic function(Args) getNative(string mangled)
{
    return syms[mangled];
}