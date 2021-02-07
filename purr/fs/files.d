module purr.fs.files;

import purr.fs.memory;
import purr.srcloc;
import std.file;

MemoryDirectory fileSystem;

static this()
{
    fileSystem = new MemoryDirectory;
}

Location readFile(string path)
{
    if (MemoryFile* file = path in fileSystem)
    {
        if (MemoryTextFile textfile = cast(MemoryTextFile) *file)
        {
            return path.readMemFile.location;
        }
    }
    return Location(1, 1, path, path.readText);
}

MemoryTextFile readMemFile(string path)
{
    if (MemoryFile *pfile = path in fileSystem)
    {
        MemoryFile file = *pfile;
        while (true)
        {
            if (MemorySymbolicLink symlink = cast(MemorySymbolicLink) file)
            {
                file = symlink.symlink;
            }
            else
            {
                break;
            }
        }
        if (MemoryTextFile textfile = cast(MemoryTextFile) file)
        {
            return textfile;
        }
    }
    return null;
}

bool isMemFile(string path)
{
    return (path in fileSystem) !is null;
}