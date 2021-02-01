module unicode.plugin;

import std.stdio;
import purr.base;
import purr.dynamic;
import purr.plugin.plugin;
import unicode.getname;

Dynamic unictrl(Args args)
{
    if (args.length == 2)
    {
        db[args[0].str] = args[1].as!uint;
        return Dynamic.nil;
    }
    if (args.length == 1)
    {
        return args[0].str.getUnicode.dynamic;
    }
    throw new Exception("not enough arguments to internal unicode function");
}

extern(C) Plugin paka_get_library_plugin()
{
    Plugin plugin = new Plugin;
    plugin.libs ~= Pair("_unicode_ctrl", &unictrl);
    return plugin; 
}
