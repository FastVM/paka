module purr.plugin.plugin;

import purr.ast.ast;
import std.conv : to;
import purr.srcloc;

final class Plugin {
    Node function(SrcLoc code)[string] parsers;

    version (repr) override string toString() {
        string ret;
        ret ~= "Plugin(langs: ";
        ret ~= parsers.length.to!string;
        ret ~= ")";
        return ret;
    }
}
