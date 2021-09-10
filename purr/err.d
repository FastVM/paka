module purr.err;

import std.stdio;
import core.stdc.stdlib : exit;

void vmError(string src) {
    stderr.writeln(src);
    exit(1);
    assert(false);
}

void vmFail(string src) {
    throw new Exception(src);
}
