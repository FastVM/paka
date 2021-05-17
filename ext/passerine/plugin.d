module ext.passerine.plugin;

import ext.passerine.base;
import ext.passerine.parse.parse;
import purr.plugin.plugin;
import purr.plugin.plugins;

shared static this()
{
    thisPlugin.addPlugin;
}

Plugin thisPlugin()
{
    Plugin plugin = new Plugin;
    plugin.libs ~= passerineBaseLibs;
    plugin.parsers["passerine"] = &parse;
    return plugin;
}

extern (C) Plugin purr_get_library_plugin()
{
    return thisPlugin;
}
