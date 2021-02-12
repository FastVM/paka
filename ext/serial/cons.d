module serial.cons;

import std.stdio;
import std.json;
import std.conv;
import purr.base;
import purr.dynamic;
import purr.plugin.plugin;
import purr.plugin.plugins;
import serial.tojson;
import serial.fromjson;

Dynamic serialdumps(Dynamic[] args)
{
    string got = args[0].serialize;
    return got.dynamic;
}

Dynamic serialreads(Dynamic[] args)
{
    writeln(args[0].str.parseJSON.toPrettyString);
    return args[0].str.parseJSON.deserialize!Dynamic;
}
