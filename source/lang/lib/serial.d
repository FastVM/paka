module lang.lib.serial;

import lang.serial;
import lang.dynamic;
import std.json;
import std.file;
import std.conv;
import std.stdio;
import core.memory;

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
    return str.parseJSON.readjs!Dynamic;
}

Dynamic libdump(Args args)
{
    return dynamic(args[0].js.to!string);
}

Dynamic libundump(Args args)
{
    return args[0].str.parseJSON.readjs!Dynamic;
}

Dynamic libresumef(Args args)
{
    string str = cast(string) read(args[0].str);
    loadState(str.parseJSON);
    return dynamic(false);
}