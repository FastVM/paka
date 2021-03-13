module purr.fs.files;

import purr.fs.memory;
import purr.srcloc;
import std.file;

__gshared MemoryDirectory fileSystem;

shared static this()
{
    fileSystem = new MemoryDirectory;
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