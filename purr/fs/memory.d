module purr.fs.memory;

import purr.srcloc;
import purr.io;
import std.file;
import std.datetime.systime;

MemoryFile flagsFrom(MemoryFile to, MemoryFile from)
{
    to.copyFuncs = from.copyFuncs;
    return to;
}

class MemoryFile
{
    MemoryFile parent;
    void delegate(MemoryFile* oldFile, MemoryFile newFile)[] copyFuncs;

    final MemoryFile copy()
    {
        return copySelf.flagsFrom(this);
    }

    MemoryFile copySelf()
    {
        assert(false);
    }
}

class MemoryDirectory : MemoryFile
{
    private MemoryFile[string] entries = null;

    override MemoryFile copySelf()
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
        MemoryFile *oldFile = name in this;
        foreach (copyFunc; file.copyFuncs)
        {
            copyFunc(oldFile, copy);   
        }
        entries[name] = copy;
        return copy;
    }

    void remove(string name)
    {
        entries[name].parent = null;
        entries.remove(name);
    }

    MemoryDirectory opOpAssign(string op : "~")(MemoryDirectory other)
    {
        foreach (name, file; other.entries)
        {
            this[name] = other[name].copy;
        }
        return this;
    }

    MemoryDirectory opBinary(string op : "~")(MemoryDirectory other)
    {
        MemoryDirectory ret = copy;
        ret ~= other;
        return ret;
    }

    MemoryFile* opBinaryRight(string op : "in")(string name)
    {
        return name in entries;
    }

    MemoryFile opIndex(string name)
    {
        if (MemoryFile* pfile = name in entries)
        {
            return *pfile;
        }
        throw new Exception("cannot open: " ~ name);
    }

    int opApply(scope int delegate(string, MemoryFile) dg) {
    
        foreach (key, val; entries) {
            if (int result = dg(key, val))
            {
                return result;
            }
        }
    
        return 0;
    }
}

class MemorySymbolicLink : MemoryFile
{
    MemoryFile symlink;

    this(MemoryFile sl)
    {
        symlink = sl;
    }

    override MemoryFile copySelf()
    {
        return cast(MemoryFile) new MemorySymbolicLink(symlink.copy);
    }
}

class MemoryTextFile : MemoryFile
{
    immutable SrcLoc location;
    bool isSync;
    SysTime syncTime;

    this(SrcLoc loc, bool sync=false, SysTime st=SysTime.min)
    {
        location = loc;
        isSync = sync;
        syncTime = st;
    }

    override MemoryFile copySelf()
    {
        return cast(MemoryFile) new MemoryTextFile(location, isSync, syncTime);
    }
}
