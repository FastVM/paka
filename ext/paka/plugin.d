module ext.paka.plugin;

import ext.paka.parse.parse: parse, parseRaw, parsePrelude;
import purr.plugin.plugin: Plugin;
import purr.plugin.plugins: addPlugin;

shared static this() {
    thisPlugin.addPlugin;
}

Plugin thisPlugin() {
    Plugin plugin = new Plugin;
    plugin.parsers["paka"] = &parse;
    plugin.parsers["paka.raw"] = &parseRaw;
    plugin.parsers["paka.prelude"] = &parsePrelude;
    return plugin;
}
