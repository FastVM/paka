module ext.paka.plugin;

import ext.paka.parse.parse;
import purr.plugin.plugin;
import purr.plugin.plugins;

shared static this() {
    thisPlugin.addPlugin;
}

Plugin thisPlugin() {
    Plugin plugin = new Plugin;
    plugin.parsers["paka"] = &parseRaw;
    plugin.parsers["paka.prelude"] = &parsePrelude;
    return plugin;
}
