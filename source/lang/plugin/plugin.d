module lang.plugin.plugin;

import std.conv;
import lang.base;
import lang.ast;

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
