module purr.plugin.plugin;

import purr.ast.ast: Node;
import std.conv : to;
import purr.srcloc: SrcLoc;

final class Plugin {
    Node function(SrcLoc code)[string] parsers;
    string function(Node)[string] undo;

    version (repr) override string toString() {
        string ret;
        ret ~= "Plugin(langs: ";
        ret ~= parsers.length.to!string;
        ret ~= ")";
        return ret;
    }
}
