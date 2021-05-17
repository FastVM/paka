module purr.srcloc;

import std.conv;

struct Location
{
    size_t line = 0;
    size_t column = 1;
    string file;
    string src;

    string pretty() {
        return line.to!string ~ ":" ~ column.to!string;
    }

    Location dup()
    {
        Location loc;
        loc.line = line;
        loc.column = column;
        loc.file = file;
        loc.src = src;
        return loc;
    }

    bool isAt(Location other)
    {
        return line == other.line && column == other.column;
    }
}

struct Span
{
    Location first;
    Location last;

    string pretty() {
        return "from " ~ first.pretty ~ " to " ~ last.pretty;
    }

    Span dup()
    {
        Span ret;
        ret.first = first.dup;
        ret.last = last.dup;
        return ret;
    }
}
