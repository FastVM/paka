module ext.paka.plugin;

import ext.paka.parse.parse: parseRaw, parsePrelude;
import purr.plugin.plugin: Plugin;
import purr.plugin.plugins: addPlugin;

shared static this() {
    thisPlugin.addPlugin;
}

Plugin thisPlugin() {
    Plugin plugin = new Plugin;
    plugin.parsers["paka"] = &parseRaw;
    plugin.parsers["paka.prelude"] = &parsePrelude;
    return plugin;
}
