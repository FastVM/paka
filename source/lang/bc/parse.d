module lang.bc.parse;

import std.conv;
import std.stdio;
import std.algorithm;
import lang.base;
import lang.bytecode;
import lang.bc.iterator;
import lang.dynamic;

// TODO: complete this module
struct InstructionSpec
{
    string name;
    Dynamic[string] values;
}

bool isWhite(char chr)
{
    return "\t\r\n ".canFind(chr);
}

bool isDigit(char chr)
{
    return "0123456789".canFind(chr);
}

void strip(ref string code)
{
    while (code.length != 0 && code[0].isWhite)
    {
        code = code[1 .. $];
    }
}

string readName(ref string code)
{
    string ret;
    while (code.length != 0 && !code[0].isWhite && code[0] != '=' && code[0] != ':')
    {
        ret ~= code[0];
        code = code[1 .. $];
    }
    return ret;
}

Dynamic readValue(Function within, ref string code)
{
    if (code.length == 0) {
        return Dynamic.nil;
    }
    if (code[0] == '"') {
        string ret = "";
        while (code.length != 0 && code[0] != '"') {
            ret ~= code[0];
            code = code[1..$];
        }
        return ret.dynamic;
    }
    if (code[0] == '{') {
        code = code[1 .. $];
        Function func = within.readBody(code);
        if (code.length != 0 && code[0] == '}') {
            code = code[1 .. $];
        }
        return func.dynamic;
    }
    if (code[0].isDigit) {
        return code.readName.to!double.dynamic;
    }
    return code.readName.dynamic;
}

InstructionSpec readInstr(Function within, ref string code)
{
    InstructionSpec spec;
    spec.name = code.readName;
    code.strip;
    while (code.length != 0 && !code[0] != '\n' && code[0] != '}') {
        string key = code.readName;
        code = code[1 .. $];
        Dynamic value = within.readValue(code);
        spec.values[key] = value;
    }
    return spec;
}

Function readBody(Function within, ref string code)
{
    Function ret = new Function;
    code.strip;
    while (code.length != 0 && code[0] == '.')
    {
        code = code[1 .. $];
        InstructionSpec got = within.readInstr(code);
        code.strip;
    }
    while (code.length != 0 && code[0] != '}') {
        if (code[0].isDigit) {
            code.readName;
            code = code[1 .. $];
            code.strip;
        }
        InstructionSpec got = within.readInstr(code);
        code.strip;
    }
    return ret;
}

Function parseBytecode(size_t ctx, string code)
{
    return baseFunction(ctx).readBody(code);
}
