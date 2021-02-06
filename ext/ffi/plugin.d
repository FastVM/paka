module ffi.plugin;

import std.stdio;
import purr.base;
import purr.plugin.plugin;
import purr.plugin.plugins;
import ffi.base;

static this()
{
    thisPlugin.addPlugin;
}

Plugin thisPlugin()
{
    Plugin plugin = new Plugin;
    plugin.libs.addLib("ffi", libffi);
    return plugin; 
}

export extern(C) Plugin purr_get_library_plugin()
{
    return thisPlugin;
}
