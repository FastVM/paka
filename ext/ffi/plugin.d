module ffi.plugin;

import std.stdio;
import purr.base;
import purr.plugin.plugin;
import ffi.base;

extern(C) Plugin paka_get_library_plugin()
{
    Plugin plugin = new Plugin;
    plugin.libs.addLib("ffi", libffi);
    return plugin; 
}
