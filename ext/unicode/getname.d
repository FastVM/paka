module ext.unicode.getname;

import std.algorithm;
import std.array;
import std.conv;
import std.string;
import std.file;
import purr.io;
import std.utf;

int[string] db;
string[int] revdb;

class UnicodeException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }
}

void build()
{
    if (db is null)
    {
        size_t count;
        foreach (line; import("UnicodeData.txt").splitter("\n"))
        {
            scope (exit)
            {
                count++;
            }
            if (line.length < 4)
            {
                continue;
            }
            size_t begin = line.indexOf(';');
            int hex = line[0 .. begin].to!int(16);
            begin++;
            size_t end = begin;
            while (line[end] != ';')
            {
                end++;
            }
            string name = line[begin .. end].toUpper;
            if (name == "<control>")
            {
                begin = line.length-5;
                end = begin;
                while (line[begin] != ';')
                {
                    begin--;
                }
                name = line[begin+1 .. end+1].idup;
            }
            db[name] = hex;
            revdb[hex] = name;
        }
    }
}

string getUnicode(string arg)
{
    build;
    string find = arg.toUpper;
    if (int* unicode = find in db)
    {
        return [cast(dchar)*unicode].toUTF8;
    }
    string[] bests;
    size_t bestdist = find.length + 1;
    foreach (key, value; db)
    {
        size_t dist = levenshteinDistance(key, find);
        if (dist < bestdist)
        {
            bestdist = dist;
            bests = null;
        }
        if (bestdist == dist)
        {
            bests ~= key;
        }
    }
    assert(bests.length != 0);
    if (bests.length == 1)
    {
        string msg = "unicode character not found: " ~ find ~ " did you mean: " ~ bests[0];
        throw new Exception(msg);
    }
    else if (bests.length <= 5)
    {
        string msg = "unicode character not found: " ~ find ~ " did you mean one of:";
        foreach (best; bests)
        {
            msg ~= " ";
            msg ~= best;
        }
        throw new Exception(msg);
    }
    else {
        string msg = "unicode character not found: " ~ find ~ " did you mean one of:";
        foreach (best; bests[0..3])
        {
            msg ~= " ";
            msg ~= best;
        }
        msg ~= " # " ~ bests[$-3..$].length.to!string ~ " more not shown";
        throw new Exception(msg);
    }
}
