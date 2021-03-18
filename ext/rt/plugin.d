module ext.rt.plugin;

import purr.io;
import purr.base;
import purr.dynamic;
import purr.plugin.plugin;
import purr.plugin.plugins;
import ext.rt.purr;

static this()
{
    thisPlugin.addPlugin;
}

Plugin thisPlugin()
{
    Plugin plugin = new Plugin;
    plugin.libs.addLib("purr", libpurr);
    return plugin;
}

export extern (C) Plugin purr_get_library_plugin()
{
    return thisPlugin;
}
