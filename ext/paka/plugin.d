module paka.plugin;

import paka.walk;
import paka.base;
import paka.parse;
import purr.plugin.plugin;
import purr.plugin.plugins;

shared static this()
{
    thisPlugin.addPlugin;
}

Plugin thisPlugin()
{
    Plugin plugin = new Plugin;
    plugin.libs ~= pakaBaseLibs;
    plugin.parsers["paka"] = code => parse(code);
    return plugin;
}

extern (C) Plugin purr_get_library_plugin()
{
    return thisPlugin;
}
