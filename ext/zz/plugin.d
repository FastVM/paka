module ext.zz.plugin;

import std.stdio;
import std.array;
import std.conv;
import purr.err;
import purr.srcloc;
import purr.ast.ast;
import purr.plugin.plugin;
import purr.plugin.plugins;
import ext.zz.zrepr;
import ext.zz.parse;
import ext.zz.walk;

static this() {
    thisPlugin.addPlugin;
}

Node parse(SrcLoc loc) {
    Node pre = loc.src.split("\n").parseLines;
    Macros macros = new Macros(size_t.max);
    Node ret;
    macros.walk(pre, ret);
    return ret;
}

Plugin thisPlugin() {
    Plugin plugin = new Plugin;
    plugin.parsers["zz"] = &parse;
    plugin.undo["zz"] = &tozz;
    return plugin;
}
