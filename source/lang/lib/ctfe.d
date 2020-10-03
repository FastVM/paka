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
    // return dynamic(cast(string) args[0].str.read);
    // return dynamic(import("entry.dext"));
    return Dynamic.nil;
}

Dynamic ctfelibentry(Dynamic[] args)
{
    // Node node = parse(cast(string) args[0].str.read);
    // Node node = parse(import("entry.dext"));
    // Walker walker = new Walker;
    // Function func = walker.walkProgram!true(node);
    // func.captured = loadCtfeBase;
    // Dynamic retval = run(func);
    // return retval;
    return Dynamic.nil;
}
