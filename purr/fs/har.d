module purr.fs.har;

import purr.io;
import std.string;
import std.algorithm;
import purr.fs.memory;
import purr.fs.files;
import purr.srcloc;

MemoryDirectory parseHar(Location loc, MemoryDirectory dir)
{
    string[] names = [];
    string file;
    bool lastWasData = false;
    size_t lno = loc.line;
    size_t ilno = loc.line;

    void insert()
    {
        foreach (name; names)
        {
            if (name == "__main__")
            {
                dir[name] = new MemoryTextFile(Location(ilno, 1, loc.file, file));
            }
            else
            {
                dir[name] = new MemoryTextFile(Location(ilno, 1, name, file));
            }
        }
        names = null;
        file = null;
    }

    void process(string line)
    {
        if (line.startsWith("---"))
        {
            insert;
            names ~= line[3 .. $].strip;
            lastWasData = false;
        }
        else
        {
            if (!lastWasData)
            {
                ilno = lno;
            }
            file ~= line;
            file ~= '\n';
            lastWasData = true;
        }
    }
    
    process("--- __main__");
    foreach (line; loc.src.splitter("\n"))
    {
        process(line);
        lno++;
    }
    insert;
    return dir;
}
