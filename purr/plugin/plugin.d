module purr.plugin.plugin;

import purr.ast.ast;
import purr.base;
import std.conv;
import purr.srcloc;

class Plugin
{
    Pair[] libs;
    Node delegate(Location code)[string] parsers;

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
