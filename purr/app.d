module purr.app;

import purr.ir.repr;
import purr.ir.walk;
import purr.ir.emit;
import purr.vm;
import purr.srcloc;
import purr.base;
import purr.ast;
import purr.base;
import purr.dynamic;
import purr.parse;
import purr.inter;
import purr.plugin.loader;
import purr.fs.files;
import purr.fs.disk;
import std.uuid;
import std.path;
import std.stdio;
import std.array;
import std.file;
import std.algorithm;
import std.process;
import std.conv;
import std.string;
import std.getopt;
import core.stdc.stdlib;

void domain(string[] args)
{
    args = args[1 .. $];
    string[] extargs;
    bool echo = false;
    void delegate()[] todo;
    size_t ctx = enterCtx;
    langNameDefault = "paka";
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
            todo ~= {
                parse(Location(1, 1, "__main__"), langNameDefault ~ ".repl");
            };
            break;
        case "--file":
            string filename = extargs[$ - 1];
            extargs.length--;
            todo ~= {
                Location code = Location(1, 1, filename, filename.readText);
                string cdir = getcwd;
                scope (exit)
                {
                    cdir.chdir;
                }
                filename.dirName.chdir;
                Dynamic retval = ctx.eval(code);
                if (echo)
                {
                    writeln(retval);
                }
            };
            break;
        case "--eval":
            string code = extargs[$ - 1];
            extargs.length--;
            todo ~= {
                Dynamic retval = ctx.eval(Location(1, 1, "__main__", code));
                if (echo)
                {
                    writeln(retval);
                }
            };
            break;
        case "--load":
            string load = extargs[$ - 1];
            extargs.length--;
            todo ~= (){
                linkLang(load);
            };
            break;
        case "--lang":
            string langname = extargs[$ - 1];
            extargs.length--;
            todo ~= (){
                langNameDefault = langname;
            };
            break;
        case "--bytecode":
            todo ~= (){
                dumpbytecode = !dumpbytecode;
            };
            break;
        case "--echo":
            todo ~= (){
                echo = !echo;
            };
            break;
        }
    }
    if (extargs.length != 0)
    {
        throw new Exception("unknown args: consider adding --file");
    }
    foreach_reverse (fun; todo)
    {
        fun();
    }
}

/// the main function that handles runtime errors
void trymain(string[] args)
{
    try
    {
        domain(args);
    }
    catch (Exception e)
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
        throw e;
    }
}

void main(string[] args)
{
    trymain(args);
}
