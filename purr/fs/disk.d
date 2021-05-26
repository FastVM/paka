module purr.fs.disk;

import purr.io;
import std.file;
import purr.fs.files;
import purr.fs.memory;
import purr.srcloc;
import core.thread;
import std.parallelism;
import std.concurrency;
import std.functional;
import std.container;
import std.datetime.stopwatch;
import std.datetime.systime;

__gshared StopWatch watch;

shared static this()
{
    watch = StopWatch(AutoStart.yes);
}

void dumpToFile(string filename, string data)
{
    File file = File(filename, "w");
    file.write(data);
    file.close();
}

bool fsexists(string path)
{
    return !(path !in fileSystem) || exists(path);
}

SrcLoc readFile(string path)
{
    // if (MemoryFile* file = path in fileSystem)
    // {
    //     if (MemoryTextFile textFile = cast(MemoryTextFile)*file)
    //     {
    //         return path.readMemFile.location;
    //     }
    // }
    return SrcLoc(1, 1, path, path.readText);
}
