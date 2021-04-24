module purr.app;

import purr.io;
import purr.repl;
import purr.ir.repr;
import purr.ir.walk;
import purr.ir.emit;
import purr.vm;
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
import core.memory;
import core.stdc.stdlib;

alias Thunk = void delegate();

__gshared size_t ctx = size_t.max;
__gshared Dynamic[] dynamics;
__gshared Dynamic[] fileArgs;
Thunk cliFileHandler(immutable string filename)
{
    return {
        string oldLang = langNameDefault;
        scope(exit)
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

Thunk cliCallHandler(immutable string code)
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
    return { writeln(dynamics[$ - 1]); dynamics.length--; };
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
            loadBaseObject(ctx, bases[$-1].tab.table);
        }
        else
        {
            rootBases[ctx].addLib("repl", librepl);
        }
        while (true)
        {
            bases ~= ctx.baseObject().dynamic;
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
                    loadBaseObject(ctx, bases[$-1].tab.table);
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
        }
    };
}

void domain(string[] args)
{
    args = args[1 .. $];
    string[] extargs;
    Thunk[] todo;
    langNameDefault = "passerine";
    ctx = enterCtx;
    scope (exit)
    {
        exitCtx;
    }
    foreach_reverse (arg; args)
    {
        switch (arg)
        {
        default:
            extargs ~= arg;
            break;
        case "--repl":
            todo ~= cliReplHandler;
            break;
        case "--serial":
            string filename = extargs[$ - 1];
            extargs.length--;
            todo ~= filename.cliSerialHandler;
            break;
        case "--file":
            string filename = extargs[$ - 1];
            extargs.length--;
            todo ~= filename.cliFileHandler;
            break;
        case "--arg":
            string filearg = extargs[$ - 1];
            extargs.length--;
            todo ~= filearg.cliArgHandler;
            break;
        case "--chain":
            string code = extargs[$ - 1];
            extargs.length--;
            todo ~= code.cliChainHandler;
            break;
        case "--call":
            string code = extargs[$ - 1];
            extargs.length--;
            todo ~= code.cliCallHandler;
            break;
        case "--eval":
            string code = extargs[$ - 1];
            extargs.length--;
            todo ~= code.cliEvalHandler;
            break;
        case "--lang":
            string langname = extargs[$ - 1];
            extargs.length--;
            todo ~= langname.cliLangHandler;
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
    foreach (arg; extargs)
    {
        Thunk th = arg.cliFileHandler;
        th();
    }
}

void thrown(Err)(Err e)
{
    size_t[] nums;
    size_t[] times;
    string[] files;
    size_t ml = 0;
    foreach (i; spans)
    {
        if (nums.length != 0 && nums[$ - 1] == i.first.line)
        {
            times[$ - 1]++;
        }
        else
        {
            nums ~= i.first.line;
            files ~= i.first.file;
            times ~= 1;
            ml = max(ml, i.first.line.to!string.length);
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
    spans.length = 0;
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
