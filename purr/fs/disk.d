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

StopWatch watch;

static this()
{
    watch = StopWatch(AutoStart.yes);
}

bool syncFile(string filename)
{
    if (MemoryFile* pfile = filename in fileSystem)
    {
        if (MemoryTextFile textFile = cast(MemoryTextFile)*pfile)
        {
            File file = File(filename, "w");
            file.write(textFile.location.src);
            file.close();
            return true;
        }
    }
    return false;
}

void dumpToFile(string filename, string data)
{
    Location loc = Location(1, 1, filename, data);
    MemoryTextFile memfile = new MemoryTextFile(loc, true, filename.timeLastModified);
    fileSystem[filename] = memfile;
}

Location readFile(string path)
{
    if (MemoryFile* file = path in fileSystem)
    {
        if (MemoryTextFile textFile = cast(MemoryTextFile)*file)
        {
            return path.readMemFile.location;
        }
    }
    return Location(1, 1, path, path.readText);
}
