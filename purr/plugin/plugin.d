module purr.plugin.plugin;

import purr.ast;
import purr.base;
import std.conv;

class Plugin
{
    Pair[] libs;
    Node delegate(string code)[string] parsers;
    Node delegate(Node[])[string] transformers;

    override string toString()
    {
        string ret;
        ret ~= "Plugin(syms: ";
        ret ~= libs.length.to!string;
        ret ~= ", langs: ";
        ret ~= parsers.length.to!string;
        ret ~= ", transformers: ";
        ret ~= transformers.length.to!string;
        ret ~= ")";
        return ret;
    }
}
