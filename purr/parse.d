module purr.parse;

import std.conv;
import std.stdio;
import purr.ast;
import purr.ir.walk;
import purr.bytecode;
import purr.base;
import purr.dynamic;
import purr.vm;
import purr.error;

enum string bashLine = "#!";
enum string langLine = "#?";

string langNameDefault = "ir";

Node delegate(string code)[string] parsers;

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

Node parse(string code, string langname = langNameDefault)
{
    if (auto i = langname in parsers)
    {
        return (*i)(code);
    }
    else
    {
        writeln(langname);
        throw new CompileException("language not found: " ~ langname);
    }
}
