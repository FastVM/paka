module ext.bind.plugin;

import purr.io;
import core.stdc.math;
import purr.base;
import purr.dynamic;
import purr.plugin.plugin;
import purr.plugin.plugins;
import ext.bind.bind;

shared static this()
{
    thisPlugin.addPlugin;
}

Plugin thisPlugin()
{
    Plugin plugin = new Plugin;
    plugin.libs.addLib("ffi", ffilib);
    return plugin;
}
