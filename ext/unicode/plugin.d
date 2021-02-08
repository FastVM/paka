module unicode.plugin;

import std.stdio;
import purr.base;
import purr.dynamic;
import purr.plugin.plugin;
import purr.plugin.plugins;
import unicode.getname;

static this()
{
    thisPlugin.addPlugin;
}

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

Plugin thisPlugin()
{
    Plugin plugin = new Plugin;
    plugin.libs ~= Pair("_unicode_ctrl", &unictrl);
    return plugin;
}

export extern (C) Plugin purr_get_library_plugin()
{
    return thisPlugin;
}
