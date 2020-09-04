module lang.lib.serial;

import lang.serial;
import lang.dynamic;
import lang.vm;
import lang.base;
import lang.json;
import std.file;
import std.conv;
import std.stdio;
import core.memory;

Pair[] libjson()
{
    Pair[] ret = [
        Pair("dumpf", dynamic(&libdumpf)),
        Pair("dump", dynamic(&libdump)),
        Pair("undump", dynamic(&libundump)),
        Pair("resumef", dynamic(&libresumef)),
        Pair("undumpf", dynamic(&libundumpf)),
    ];
    return ret;
}

private:
Dynamic libdumpf(Args args)
{
    File file = File(args[0].str, "w");
    if (args.length == 1)
    {
        file.write(saveState);
    }
    else
    {
        file.write(args[1].js);
    }
    file.close;
    return dynamic(false);
}

Dynamic libundumpf(Args args)
{
    string str = cast(string) read(args[0].str);
    return str.serialParse.readjs!Dynamic;
}

Dynamic libdump(Args args)
{
    return dynamic(args[0].js.to!string);
}

Dynamic libundump(Args args)
{
    Dynamic ret = args[0].str.serialParse.readjs!Dynamic;
    return ret;
}

Dynamic libresumef(Args args)
{
    string str = cast(string) read(args[0].str);
    loadState(str.serialParse);
    return dynamic(false);
}