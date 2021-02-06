module purr.fs.files;

import purr.fs.memory;
import std.file;

MemoryDirectory fileSystem;

static this()
{
    fileSystem = new MemoryDirectory;
}

string readFile(string path)
{
    if (MemoryFile* file = path in fileSystem)
    {
        if (MemoryTextFile textfile = cast(MemoryTextFile) *file)
        {
            return textfile.data;
        }
    }
    return path.readText;
}