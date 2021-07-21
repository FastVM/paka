module purr.srcloc;

import std.conv;

struct SrcLoc {
    size_t line = 0;
    size_t column = 1;
    string file;
    string src;

    string pretty() {
        return line.to!string ~ ":" ~ column.to!string;
    }

    SrcLoc dup() {
        SrcLoc loc;
        loc.line = line;
        loc.column = column;
        loc.file = file;
        loc.src = src;
        return loc;
    }

    size_t where() {
        size_t myline = 1;
        size_t mycol = 1;
        foreach (i, c; src) {
            if (myline == line && mycol == column) {
                return i;
            }
            if (c == '\n') {
                myline += 1;
                mycol = 1;
            } else {
                mycol += 1;
            }
        }
        assert(false);
    }

    bool isAt(SrcLoc other) {
        return line == other.line && column == other.column;
    }
}

struct Span {
    SrcLoc first;
    SrcLoc last;

    string pretty() {
        return "from " ~ first.pretty ~ " to " ~ last.pretty;
    }

    string src() {
        return first.src[first.where .. last.where];
    }

    Span dup() {
        Span ret;
        ret.first = first.dup;
        ret.last = last.dup;
        return ret;
    }
}
