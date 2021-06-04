module purr.app;

import purr.io;
import purr.repl;
import purr.ir.repr;
import purr.ir.opt;
import purr.ir.walk;
import purr.vm;
import purr.srcloc;
import purr.base;
import purr.ast.ast;
import purr.dynamic;
import purr.parse;
import purr.inter;
import purr.io;
import purr.fs.files;
import purr.fs.disk;
import purr.vm.bytecode;
import purr.ir.walk;
import std.uuid;
import std.path;
import std.array;
import std.file;
import std.json;
import std.ascii;
import std.algorithm;
import std.process;
import std.conv;
import std.string;
import std.getopt;
import std.datetime.stopwatch;
import core.memory;
import core.time;
import core.stdc.stdlib;

extern (C) __gshared string[] rt_options = [];

alias Thunk = void delegate();

__gshared size_t ctx = size_t.max;
__gshared Dynamic[] dynamics;
__gshared Dynamic[] fileArgs;
Thunk cliFileHandler(immutable string filename)
{
    return {
        string oldLang = langNameDefault;
        scope (exit)
        {
            langNameDefault = oldLang;
        }
        if (filename.endsWith(".paka"))
        {
            langNameDefault = "paka";
        }
        if (filename.endsWith(".pn"))
        {
            langNameDefault = "passerine";
        }
        SrcLoc code = SrcLoc(1, 1, filename, filename.readText);
        string cdir = getcwd;
        Dynamic retval;
        scope (exit)
        {
            cdir.chdir;
            fileArgs = null;
        }
        filename.dirName.chdir;
        retval = ctx.eval(code, fileArgs);
        dynamics ~= retval;
    };
}

Thunk cliArgHandler(immutable string arg)
{
    return { fileArgs ~= arg.dynamic; };
}

Thunk cliFormHandler(immutable string code)
{
    return {
        Dynamic got = dynamics[$ - 1]([
                ctx.eval(SrcLoc(1, 1, "__main__", code))
                ]);
        dynamics.length--;
        dynamics ~= got;
    };
}

Thunk cliEvalHandler(immutable string code)
{
    return {
        scope (exit)
        {
            fileArgs = null;
        }
        Dynamic got = ctx.eval(SrcLoc(1, 1, "__main__", code), fileArgs);
        dynamics ~= got;
    };
}

Thunk cliParseHandler(immutable string code)
{
    return {
        SrcLoc loc = SrcLoc(1, 1, "__main__", code);
        Node res = loc.parse;
    };
}

Thunk cliValidateHandler(immutable string code)
{
    return {
        SrcLoc loc = SrcLoc(1, 1, "__main__", code);
        Node node = loc.parse;
        Walker walker = new Walker;
        BasicBlock func = walker.walkBasicBlock(node, ctx);
    };
}

Thunk cliCompileHandler(immutable string code)
{
    return {
        SrcLoc loc = SrcLoc(1, 1, "__main__", code);
        Node node = loc.parse;
        Walker walker = new Walker;
        Bytecode func = walker.walkProgram(node, ctx);
    };
}

Thunk cliLangHandler(immutable string langname)
{
    return { langNameDefault = langname; };
}

Thunk cliAstHandler()
{
    return { dumpast = !dumpast; };
}

Thunk cliIrHandler()
{
    return { dumpir = !dumpir; };
}

Thunk cliEchoHandler()
{
    return {
        if (dynamics[$ - 1].isString)
        {
            writeln(dynamics[$ - 1].str);
        }
        else
        {
            writeln(dynamics[$ - 1].to!string);
        }
        dynamics.length--;
    };
}

Thunk cliIntoHandler(string filename)
{
    return {
        File file = File(filename, "w");
        if (dynamics[$ - 1].isString)
        {
            file.write(dynamics[$ - 1].str);
        }
        else
        {
            file.write(dynamics[$ - 1].to!string);
        }
        dynamics.length--;
    };
}

Thunk cliSerialHandler(string filename)
{
    return { serialFile = filename; };
}

__gshared string serialFile = null;
__gshared Dynamic[] bases = null;

Thunk cliReplHandler()
{
    return {
        bases = [];
        rootBases[ctx].addLib("repl", librepl);
        while (true)
        {
        // before:
            string prompt = "(" ~ to!string(bases.length + 1) ~ ")> ";
            string line = null;
            line = readln(prompt);
            while (line.length > 0)
            {
                if (line[0].isWhite)
                {
                    line = line[1 .. $];
                }
                else if (line[$ - 1].isWhite)
                {
                    line = line[0 .. $ - 1];
                }
                else
                {
                    break;
                }
            }
            SrcLoc code = SrcLoc(bases.length, 1, "__main__", line);
            if (code.src.length == 0)
            {
                break;
            }
            Dynamic res = ctx.eval(code);
            if (res.isNil)
            {
                writeln(res);
            }
            bases ~= ctx.baseObject().dynamic;
        }
    };
}

Thunk cliTimeHandler(Thunk next)
{
    return {
        StopWatch watch = StopWatch(AutoStart.no);
        watch.start();
        next();
        watch.stop();
        writeln(watch.peek);
    };
}

Thunk cliBenchHandler(size_t n, Thunk next)
{
    return {
        Duration all;
        foreach (_; 0..n)
        {
            StopWatch watch = StopWatch(AutoStart.no);
            watch.start();
            next();
            watch.stop();
            all += watch.peek;
        }
        writeln("per run: ", all / n);
    };
}

Thunk cliRepeatHandler(size_t n, Thunk next)
{
    return {
        foreach (_; 0..n)
        {
            next();
        }
    };
}

Thunk cliOptHandler(size_t n)
{
    return {
        defaultOptLevel = n;
    };
}

void domain(string[] args)
{
    args = args[1 .. $];
    Thunk[] todo;
    langNameDefault = "paka";
    ctx = enterCtx;
    scope (exit)
    {
        exitCtx;
    }
    foreach_reverse (arg; args)
    {
        string[] parts = arg.split("=").array;
        string part1()
        {
            assert(parts.length != 0);
            if (parts.length == 1)
            {
                throw new Exception(parts[0] ~ " takes an argument using " ~ parts[0]  ~"=argument");
            }
            return parts[1..$].join("=");
        }
        bool runNow = parts[0][$-1] == ':';
        scope(exit)
        {
            if (runNow)
            {
                Thunk last = todo[$-1];
                todo.length--;
                last();
            }
        }
        if (runNow)
        {
            parts[0].length--;
        }
        switch (parts[0])
        {
        default:
            throw new Exception("use --file=" ~ parts[0]);
        case "--time":
            todo[$-1] = todo[$-1].cliTimeHandler;
            break;
        case "--repeat":
            todo[$-1] = cliRepeatHandler(part1.to!size_t, todo[$-1]);
            break;
        case "--bench":
            todo[$-1] = cliBenchHandler(part1.to!size_t, todo[$-1]);
            break;
        case "--repl":
            todo ~= cliReplHandler;
            break;
        case "--file":
            todo ~= part1.cliFileHandler;
            break;
        case "--arg":
            todo ~= part1.cliArgHandler;
            break;
        case "--parse":
            todo ~= part1.cliParseHandler;
            break;
        case "--compile":
            todo ~= part1.cliCompileHandler;
            break;
        case "--eval":
            todo ~= part1.cliEvalHandler;
            break;
        case "--lang":
            todo ~= part1.cliLangHandler;
            break;
        case "--into":
            todo ~= part1.cliIntoHandler;
            break;
        case "--opt":
            todo ~= cliOptHandler(part1.to!size_t);
            break;
        case "--ast":
            todo ~= cliAstHandler;
            break;
        case "--ir":
            todo ~= cliIrHandler;
            break;
        case "--echo":
            todo ~= cliEchoHandler;
            break;
        }
    }
    foreach_reverse (fun; todo)
    {
        fun();
    }
}

void thrown(Err)(Err e)
{
    throw e;
}

/// the main function that handles runtime errors
void trymain(string[] args)
{
    try
    {
        domain(args);
    }
    catch (Error e)
    {
        e.thrown;
    }
    catch (Exception e)
    {
        e.thrown;
    }
}

void main(string[] args)
{
    trymain(args);
}
