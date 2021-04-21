module ext.rt.plugin;

import purr.io;
import purr.base;
import purr.dynamic;
import purr.plugin.plugin;
import purr.plugin.plugins;
import ext.rt.purr;

shared static this()
{
    thisPlugin.addPlugin;
}

Plugin thisPlugin()
{
    Plugin plugin = new Plugin;
    plugin.libs.addLib("purr", libpurr);
    return plugin;
}