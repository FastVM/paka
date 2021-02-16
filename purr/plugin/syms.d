module purr.plugin.syms;
import purr.dynamic;

Dynamic function(Args)[string] syms;

Dynamic function(Args) getNative(string mangled)
{
    return syms[mangled];
}