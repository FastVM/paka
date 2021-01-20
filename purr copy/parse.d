module purr.parse;

import std.conv;
import std.stdio;
import purr.ast;
import purr.walk;
import purr.bytecode;
import purr.base;
import purr.dynamic;
import purr.vm;
import purr.error;

enum string bashLine = "#!";
enum string langLine = "#?";

string langNameDefault = "default";

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
    if (code.length > bashLine.length && code[0 .. bashLine.length] == bashLine)
    {
        code.readLine;
    }
    if (code.length > langLine.length && code[0 .. langLine.length] == langLine)
    {
        size_t ctx = enterCtx;
        scope (exit)
        {
            exitCtx;
        }
        string line = code.readLine;
        Node node = line[langLine.length .. $].parse("dext");
        Walker walker = new Walker;
        Function func = walker.walkProgram(node, ctx);
        func.captured = loadBase;
        void findLang(uint index, Dynamic* stack, Dynamic[] locals)
        {
            foreach (i, ref v; locals[0 .. func.stab.length])
            {
                if (func.stab[i] == "lang")
                {
                    if (v.type != Dynamic.Type.str) {
                        throw new TypeException("language must be a str");
                    }
                    langname = v.str;
                }
            }
        }

        run(func, null, &findLang);
    }
    if (auto i = langname in parsers)
    {
        return (*i)(code);
    }
    else if (langname == "")
    {
        throw new CompileException("language not specified");
    }
    else
    {
        throw new CompileException("language not found: " ~ langname);
    }
}
