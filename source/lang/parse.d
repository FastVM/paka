module lang.parse;

import std.conv;
import std.stdio;
import lang.ast;
import lang.dext.parse;
import lang.bf.parse;
import lang.walk;
import lang.bytecode;
import lang.base;
import lang.dynamic;
import lang.vm;
import lang.error;

string readLine(ref string code)
{
    string ret;
    while (code.length != 0 && code[0] != '\n')
    {
        ret ~= code[0];
        code = code[1 .. $];
    }
    if (code.length != 0)
    {
        code = code[1 .. $];
    }
    return ret;
}

Node parse(string code)
{
    return lang.dext.parse.parse(code);
}
