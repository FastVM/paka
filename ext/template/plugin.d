module ext.template.plugin;

import purr.io;
import purr.base;
import purr.dynamic;
import purr.plugin.plugin;
import purr.plugin.plugins;
import meta.lib.ast;

static assert(false, "please implement this library");

static this()
{
    thisPlugin.addPlugin;
}

Plugin thisPlugin()
{
    Plugin plugin = new Plugin;
    return plugin;
}

export extern (C) Plugin purr_get_library_plugin()
{
    return thisPlugin;
}
