module ext.core.plugin;

import purr.io;
import purr.base;
import purr.dynamic;
import purr.plugin.plugin;
import purr.plugin.plugins;
import ext.core.lib.io;
import ext.core.lib.sys;
import ext.core.lib.str;
import ext.core.lib.arr;
import ext.core.lib.tab;
import ext.core.lib.math;

shared static this()
{
    thisPlugin.addPlugin;
}

Pair[] ret()
{
    Pair[] ret;
    ret.addLib("str", libstr);
    ret.addLib("arr", libarr);
    ret.addLib("tab", libtab);
    ret.addLib("io", libio);
    ret.addLib("sys", libsys);
    ret.addLib("math", libmath);
    return ret;
}

Plugin thisPlugin()
{
    Plugin plugin = new Plugin;
    plugin.libs ~= ret;
    return plugin;
}