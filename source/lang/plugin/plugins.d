module lang.plugin.plugins;

import lang.plugin.plugin;
import lang.base;
import lang.walk;
import lang.parse;
import lang.ast;

Plugin[] plugins;

Pair[] pluginLib()
{
    Pair[] ret;
    foreach (plugin; plugins)
    {
        ret ~= plugin.libs;
    }
    return ret;
}

void pushPlugin(ref Node delegate(string code)[string] par, Node delegate(string code)[string] vals)
{
    foreach (key, value; vals)
    {
        par[key] = value;
    }
}

void pushPlugin(ref Node delegate(Node[])[string] tf, Node delegate(Node[])[string] vals)
{
    foreach (key, value; vals)
    {
        tf[key] = value;
    }
}

void addPlugin(Plugin plugin)
{
    plugins ~= plugin;
    pushPlugin(parsers, plugin.parsers);
    pushPlugin(transformers, plugin.transformers);
}