module passerine.magic;

import purr.io;
import std.conv;
import purr.dynamic;

Dynamic magicif(Dynamic[] args)
{
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

Dynamic magicprint(Dynamic[] args)
{
    write(args[0]);
    return Dynamic.nil;
}

Dynamic magicprintln(Dynamic[] args)
{
    writeln(args[0]);
    return Dynamic.nil;
}

Dynamic magictostring(Dynamic[] args)
{
    return args[0].to!string.dynamic;
}

Dynamic magiccall(Dynamic[] args)
{
    return args[0](args[1..$]);
}