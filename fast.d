module fast;

import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.process;
import std.path;
import std.stdio;

void run(Args...)(Args args)
{
    string[] exec;
    string cmd;
    static foreach (arg; args)
    {
        exec ~= arg.to!string;
        cmd ~= exec[$-1] ~ ' ';
    }
    auto res = execute(exec);
    assert(res.status == 0, res.output);
}

string[] find(string dir)
{
    string[] dirs = [dir];
    size_t index = 0;    
    while (index < dirs.length)
    {
        if (dirs[index].isDir)
        {
            dirs ~= dirs[index].dirEntries(SpanMode.shallow).map!(x => x.name).array;
        }
        index++;
    }
    return dirs;
}

void main(string[] args)
{
    string[] files = "source".find;
    foreach (file; files)
    {
        if (file.endsWith(".d"))
        {
            string outdir = file.dirName;
            run("dmd", "-c", file, "-od=" ~ outdir, "-Isource");
        }
    }
}