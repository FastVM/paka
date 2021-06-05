module ext.paka.plugin;

import purr.io;
import ext.paka.parse.parse;
import purr.plugin.plugin;
import purr.plugin.plugins;

shared static this()
{
    thisPlugin.addPlugin;
}

Plugin thisPlugin()
{
    Plugin plugin = new Plugin;
    plugin.parsers["paka"] = &parseUncached;
    plugin.parsers["paka.cached"] = &parseCached;
    plugin.parsers["paka.uncached"] = &parseUncached;
    return plugin;
}
