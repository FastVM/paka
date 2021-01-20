module paka.plugin;

import paka.base;
import paka.parse;
import purr.plugin.plugin;

extern(C) Plugin dext_get_library_plugin()
{
    Plugin plugin = new Plugin;
    // plugin.transformers = questTransforms;
    plugin.libs ~= dextBaseLibs;
    plugin.parsers["paka"] = code => parse(code);
    return plugin; 
}
