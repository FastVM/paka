module dext.plugin;

import dext.base;
import dext.parse;
import purr.plugin.plugin;

extern(C) Plugin dext_get_library_plugin()
{
    Plugin plugin = new Plugin;
    // plugin.transformers = questTransforms;
    plugin.libs ~= dextBaseLibs;
    plugin.parsers["dext"] = code => parse(code);
    return plugin; 
}
