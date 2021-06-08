module purr.parse;

import std.conv;
import purr.io;
import purr.ast.ast;
import purr.ir.walk;
import purr.vm.bytecode;
import purr.vm;
import purr.srcloc;

enum string bashLine = "#!";
enum string langLine = "#?";

__gshared string langNameDefault = "paka";

__gshared Node function(SrcLoc code)[string] parsers;

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

Node parse(SrcLoc code, string langname = langNameDefault)
{
    if (auto i = langname in parsers)
    {
        return (*i)(code);
    }
    else
    {
        throw new Exception("language not found: " ~ langname);
    }
}
