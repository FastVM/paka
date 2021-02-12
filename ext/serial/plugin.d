module serial.plugin;

import std.stdio;
import purr.base;
import purr.dynamic;
import purr.plugin.plugin;
import purr.plugin.plugins;
import serial.cons;

static this()
{
    thisPlugin.addPlugin;
}

Plugin thisPlugin()
{
    Plugin plugin = new Plugin;
    plugin.libs ~= FunctionPair!serialdumps("_serial_dumps");
    plugin.libs ~= FunctionPair!serialreads("_serial_reads");
    return plugin;
}

export extern (C) Plugin purr_get_library_plugin()
{
    return thisPlugin;
}
