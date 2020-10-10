module lang.lib.ctfe;

import lang.ast;
import lang.base;
import lang.bytecode;
import lang.dynamic;
import lang.dext.parse;
import lang.walk;
import lang.vm;
import std.stdio;
import std.conv;
import std.file;

Dynamic ctfelibprint(Dynamic[] args)
{
    foreach (i; args)
    {
        __ctfeWrite(i.to!string);
    }
    __ctfeWrite("\n");
    return Dynamic.nil;
}

Dynamic ctfelibread(Dynamic[] args)
{
    return Dynamic.nil;
}

Dynamic ctfelibentry(Dynamic[] args)
{
    return Dynamic.nil;
}
