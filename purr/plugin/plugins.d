module purr.plugin.plugins;

import purr.plugin.plugin: Plugin;
import purr.parse: parsers;
import purr.srcloc: SrcLoc;
import purr.ast.ast: Node;
import std.conv: to;

__gshared Plugin[] plugins;

void pushPlugin(ref Node function(SrcLoc code)[string] par, Node function(SrcLoc code)[string] vals) {
    foreach (key, value; vals) {
        par[key] = value;
    }
}

void pushPlugin(ref Node function(Node[])[string] tf, Node function(Node[])[string] vals) {
    foreach (key, value; vals) {
        tf[key] = value;
    }
}

string unparse(string name, Node node) {
    foreach (p; plugins) {
        if (auto v = name in p.undo) {
            return (*v)(node) ~ '\n';
        }
    }
    return node.to!string ~ '\n';
}

void addPlugin(Plugin plugin) {
    synchronized {
        plugins ~= plugin;
    }
    pushPlugin(parsers, plugin.parsers);
}
