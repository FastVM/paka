module quest.plugin;

import std.stdio;
import quest.walk;
import quest.base;
import quest.parse;
import lang.plugin.plugin;

extern(C) Plugin dext_get_library_plugin()
{
    Plugin plugin = new Plugin;
    plugin.transformers = questTransforms;
    plugin.libs ~= questBaseLibs;
    plugin.parsers["quest"] = code => parse(code);
    return plugin; 
}
