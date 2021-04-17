module ext.passerine.magic;

import std.stdio;
import purr.dynamic;

Dynamic magicif(Dynamic[] args)
{
    writeln(args);
    Dynamic cond = args[0].arr[0];
    if (cond.log)
    {
        return args[0].arr[1];
    }
    else
    {
        return args[0].arr[2];
    }
}