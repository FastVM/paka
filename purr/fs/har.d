module purr.fs.har;

import std.string;
import std.algorithm;
import purr.fs.memory;

MemoryDirectory parseHar(string files)
{
    MemoryDirectory dir = new MemoryDirectory;
    string[] names = ["main.paka"];
    string file;
    bool lastWasData = false;
    void insert()
    {
        foreach (name; names)
        {
            dir[name] = new MemoryTextFile(file);
        }
        names = null;
        file = null;
    }
    foreach (line; files.splitter("\n"))
    {
        if (line.startsWith("---"))
        {
            if (lastWasData)
            {
                insert;
            }
            names ~= line[3..$].strip;
            lastWasData = false;
        }
        else
        {
            file ~= line;
            file ~= '\n';
            lastWasData = true;
        }
    }
    insert;
    return dir;
}