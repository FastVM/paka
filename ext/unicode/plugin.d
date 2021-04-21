module unicode.plugin;

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
