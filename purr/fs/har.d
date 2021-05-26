module purr.fs.har;

import purr.io;
import std.string;
import std.array;
import std.algorithm;
import purr.fs.memory;
import purr.fs.files;
import purr.srcloc;

MemoryDirectory parseHar(SrcLoc loc, MemoryDirectory dir)
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
            MemoryTextFile mfile = void;
            if (name == "__main__")
            {
                mfile = new MemoryTextFile(SrcLoc(ilno, 1, loc.file, file));
            }
            else
            {
                mfile = new MemoryTextFile(SrcLoc(ilno, 1, name, file));
            }
            dir[name] = mfile;
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
