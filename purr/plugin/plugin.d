module purr.plugin.plugin;

import purr.ast.ast;
import purr.base;
import std.conv;
import purr.srcloc;

final class Plugin
{
    Pair[] libs;
    Node function(Location code)[string] parsers;

    override string toString()
    {
        string ret;
        ret ~= "Plugin(syms: ";
        ret ~= libs.length.to!string;
        ret ~= ", langs: ";
        ret ~= parsers.length.to!string;
        ret ~= ")";
        return ret;
    }
}
