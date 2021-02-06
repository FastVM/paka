module purr.fs.memory;

import std.stdio;

class MemoryFile
{
    MemoryFile parent;

    MemoryFile copy()
    {
        assert(false);
    }
}

class MemoryDirectory : MemoryFile
{
    private MemoryFile[string] entries = null;

    override MemoryFile copy()
    {
        MemoryDirectory ret = new MemoryDirectory;
        foreach (name, file; entries)
        {
            ret[name] = file.copy;
        }
        return cast(MemoryFile) ret;
    }

    MemoryFile opIndexAssign(MemoryFile file, string name)
    {
        MemoryFile copy = file.copy;
        copy.parent = this;
        entries[name] = copy;
        return copy;
    }

    MemoryDirectory opOpAssign(string op: "~")(MemoryDirectory other)
    {
        foreach (name, file; other.entries)
        {
            this[name] = other[name];
        }
        return this;
    }

    MemoryDirectory opBinary(string op: "~")(MemoryDirectory other)
    {
        MemoryDirectory ret = copy;
        ret ~= other;
        return ret;
    }
    
    MemoryFile* opBinaryRight(string op: "in")(string name)
    {
        return name in entries;
    }

    MemoryFile opIndex(string name)
    {
        if (MemoryFile *pfile = name in entries)
        {
            return *pfile;
        }
        throw new Exception("cannot open: " ~ name);
    }
}

class MemoryTextFile : MemoryFile
{
    string data;

    override MemoryFile copy()
    {
        return cast(MemoryFile) new MemoryTextFile(data);
    }

    this(string d)
    {
        data = d;
    }
}
