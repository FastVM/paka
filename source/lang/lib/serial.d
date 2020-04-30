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
    // File file = File(*args[0].value.str, "w");
    // file.write(saveState);
    // file.close;
    return dynamic(true);
}

Dynamic libresumef(Args args)
{
    string str = cast(string) read(*args[0].value.str);
    loadState(str.parseJSON);
    return dynamic(false);
}