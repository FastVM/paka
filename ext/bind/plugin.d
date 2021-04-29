module ext.ffi.plugin;

import purr.io;
import std.typecons;
import purr.base;
import purr.dynamic;
import purr.plugin.plugin;
import purr.plugin.plugins;
import ext.ffi.bind;
import ext.ffi.unbind;
import core.stdc.math;

shared static this()
{
    thisPlugin.addPlugin;
}

Plugin thisPlugin()
{
    Plugin plugin = new Plugin;
    Dynamic test = arr(bind!atan2).bind;
    plugin.libs ~= Pair("atan2", test);
    return plugin;
}