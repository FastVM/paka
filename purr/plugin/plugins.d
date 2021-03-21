module purr.plugin.plugins;

import purr.io;
import purr.plugin.plugin;
import purr.base;
import purr.ir.walk;
import purr.parse;
import purr.srcloc;
import purr.ast.ast;
import purr.srcloc;

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

void pushPlugin(ref Node delegate(Location code)[string] par, Node delegate(Location code)[string] vals)
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
}