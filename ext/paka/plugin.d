module paka.plugin;

import paka.walk;
import paka.base;
import paka.parse;
import paka.repl;
import purr.plugin.plugin;
import purr.plugin.plugins;

static this()
{
    thisPlugin.addPlugin;
}

Plugin thisPlugin()
{
    Plugin plugin = new Plugin;
    plugin.transformers = pakaTransforms;
    plugin.libs ~= pakaBaseLibs;
    plugin.parsers["paka"] = code => parse(code);
    plugin.parsers["paka.repl"] = code => replParse(code);
    return plugin;
}

extern (C) Plugin purr_get_library_plugin()
{
    return thisPlugin;
}
