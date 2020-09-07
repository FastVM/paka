module lang.json;

import std.json;
import std.conv;
import std.zlib;
import std.stdio;

alias SerialValue = JSONValue;
alias SerialType = JSONType;

// string serialToString(SerialValue value)
// {
//     string ret = cast(string) compress(cast(const(void)[]) value.to!string, 9);
//     return ret;
// }

// SerialValue serialParse(string str)
// {
//     return (cast(string) uncompress(cast(const(void)[]) str)).parseJSON;
// }

alias serialParse = parseJSON;
alias serialToString = to!string;
