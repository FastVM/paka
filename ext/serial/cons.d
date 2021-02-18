module serial.cons;

import purr.io;
import std.json;
import std.conv;
import purr.base;
import purr.dynamic;
import purr.plugin.plugin;
import purr.plugin.plugins;
import serial.tojson;
import serial.fromjson;

Dynamic serialdumps(Args args)
{
    string got = args[0].serialize;
    return got.dynamic;
}

Dynamic serialreads(Args args)
{
    return args[0].str.parseJSON.deserializeCached;
}
