module purr.app;

import purr.io;
import purr.repl;
import purr.ir.repr;
import purr.ir.walk;
import purr.ir.emit;
import purr.vm;
import purr.bugs;
import purr.srcloc;
import purr.base;
import purr.ast.ast;
import purr.dynamic;
import purr.parse;
import purr.inter;
import purr.io;
import purr.serial.fromjson;
import purr.serial.tojson;
import purr.fs.files;
import purr.fs.disk;
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
        Location code = Location(1, 1, filename, filename.readText);
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

Thunk cliChainHandler(immutable string code)
{
    return {
        Dynamic got = ctx.eval(Location(1, 1, "__main__", code))([
                dynamics[$ - 1]
                ]);
        dynamics.length--;
        dynamics ~= got;
    };
}

Thunk cliFormHandler(immutable string code)
{
    return {
        Dynamic got = dynamics[$ - 1]([
                ctx.eval(Location(1, 1, "__main__", code))
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
        Dynamic got = ctx.eval(Location(1, 1, "__main__", code), fileArgs);
        dynamics ~= got;
    };
}

Thunk cliLangHandler(immutable string langname)
{
    return { langNameDefault = langname; };
}

Thunk cliBytecodeHandler()
{
    return { dumpbytecode = !dumpbytecode; };
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
        if (dynamics[$ - 1].type == Dynamic.Type.str)
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
        if (dynamics[$ - 1].type == Dynamic.Type.str)
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
        if (serialFile !is null && serialFile.exists)
        {
            string jsonText = serialFile.readText;
            bases = jsonText.parseJSON.deserialize!(Dynamic[]);
            loadBaseObject(ctx, bases[$ - 1].tab.table);
        }
        else
        {
            rootBases[ctx].addLib("repl", librepl);
        }
        while (true)
        {
        before:
            if (serialFile !is null)
            {
                File outFile = File(serialFile, "w");
                scope (exit)
                {
                    outFile.close;
                }
                outFile.write(bases.serialize);
            }
            string prompt = "(" ~ bases.length.to!string ~ ")> ";
            string line = null;
            try
            {
                line = readln(prompt);
            }
            catch (ExitException ee)
            {
                if (ee.letter == 'Z' && bases.length > 1)
                {
                    reader.history.length--;
                    bases.length--;
                    loadBaseObject(ctx, bases[$ - 1].tab.table);
                    reader.output.write("\x1B[K\x1B[1F\x1B[1B");
                    goto before;
                }
                else
                {
                    throw ee;
                }
            }
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
            Location code = Location(bases.length, 1, "__main__", line);
            if (code.src.length == 0)
            {
                break;
            }
            Dynamic res = ctx.eval(code);
            if (res.type != Dynamic.Type.nil)
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
        case "--serial":
            todo ~= part1.cliSerialHandler;
            break;
        case "--file":
            todo ~= part1.cliFileHandler;
            break;
        case "--arg":
            todo ~= part1.cliArgHandler;
            break;
        case "--chain":
            todo ~= part1.cliChainHandler;
            break;
        case "--call":
            todo ~= part1.cliFormHandler;
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
        case "--bytecode":
            todo ~= cliBytecodeHandler;
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
    size_t[] nums;
    size_t[] times;
    string[] files;
    size_t ml = 0;
    foreach (df; debugFrames)
    {
        Span span = df.span;
        if (nums.length != 0 && nums[$ - 1] == span.first.line)
        {
            times[$ - 1]++;
        }
        else
        {
            nums ~= span.first.line;
            files ~= span.first.file;
            times ~= 1;
            ml = max(ml, span.first.line.to!string.length);
        }
    }
    string trace;
    string last = "__main__";
    foreach (i, v; nums)
    {
        if (i == 0)
        {
            trace ~= "  on line ";
        }
        else
        {
            trace ~= "from line ";
        }
        foreach (j; 0 .. ml - v.to!string.length)
        {
            trace ~= " ";
        }
        trace ~= v.to!string;
        if (files[i] != last)
        {
            last = files[i];
            trace ~= " (file: " ~ last ~ ")";
        }
        if (times[i] > 2)
        {
            trace ~= " (repeated: " ~ times[i].to!string ~ " times)";
        }
        trace ~= "\n";
    }
    debugFrames.length = 0;
    writeln(trace);
    writeln(e.msg);
    writeln;
    purr_disable_smart_reader();
    makeReader(false);
    throw e;
    exit(1);
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
