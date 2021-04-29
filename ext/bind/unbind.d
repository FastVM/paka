module ext.ffi.unbind;

import purr.io;
import std.traits;
import std.typecons;
import std.meta;
import std.conv;
import purr.dynamic;
import ext.ffi.bind;

Type unbind(Type)(Dynamic arg) if (isNumeric!Type)
{
    return arg.as!double.to!Type;
}

Type unbind(Type)(Dynamic arg) if (is(Type == string))
{
    return arg.str;
}

Type unbind(Type)(Dynamic arg) if (isArray!Type && !isSomeString!Type)
{
    Type ret;
    foreach (elem; arg.arr)
    {
        ret ~= elem.unbind!(ElementType!Type);
    }
    return ret;
}