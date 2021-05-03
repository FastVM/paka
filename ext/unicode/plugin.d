module unicode.plugin;

import std.utf;
import std.conv;
import purr.io;
import purr.base;
import purr.dynamic;
import purr.plugin.plugin;
import purr.plugin.plugins;
import unicode.getname;

shared static this()
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
        if (args[0].type == Dynamic.Type.sml)
        {
            return [cast(dchar) args[0].as!int].toUTF8.dynamic;
        }
        if ('0' <= args[0].str[0] && args[0].str[0] <= '9')
        {
            return [cast(dchar) args[0].str.to!int].toUTF8.dynamic;
        }
        return args[0].str.getUnicode.dynamic;
    }
    throw new Exception("not enough arguments to internal unicode function");
}

Plugin thisPlugin()
{
    Plugin plugin = new Plugin;
    plugin.libs ~= FunctionPair!unictrl("_unicode_ctrl");
    return plugin;
}
