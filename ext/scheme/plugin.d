module ext.scheme.plugin;

import ext.paka.parse.parse;
import purr.plugin.plugin;
import purr.plugin.plugins;

static this() {
    thisPlugin.addPlugin;
}

Plugin thisPlugin() {
    Plugin plugin = new Plugin;
    plugin.parsers["paka"] = &parseUncached;
    plugin.parsers["paka.cached"] = &parseCached;
    plugin.parsers["paka.uncached"] = &parseUncached;
    return plugin;
}