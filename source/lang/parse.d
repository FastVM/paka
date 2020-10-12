module lang.parse;

import std.conv;
import std.stdio;
import lang.ast;
import lang.dext.parse;
import lang.dext.repl;
import lang.walk;
import lang.bytecode;
import lang.base;
import lang.dynamic;
import lang.vm;
import lang.error;

enum string bashLine = "#!";
enum string langLine = "#?";

Node delegate(string code)[string] parsers;

static this()
{
    parsers["dext"] = (c) => lang.dext.parse.parse(c);
}

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

Node parse(string code, string lang = "dext")
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
        void findLang(ref size_t index, ref size_t depth, ref Dynamic[] stack, ref Dynamic[] locals)
        {
            foreach (i, ref v; locals[0 .. func.stab.byPlace.length])
            {
                if (func.stab.byPlace[i] == "lang")
                {
                    if (v.type != Dynamic.Type.str) {
                        throw new TypeException("language must be a str");
                    }
                    lang = v.str;
                }
            }
        }

        run(func, null, &findLang);
    }
    if (auto i = lang in parsers)
    {
        return (*i)(code);
    }
    else if (lang == "")
    {
        throw new CompileException("language not specified");
    }
    else
    {
        throw new CompileException("language not found: " ~ lang);
    }
}
