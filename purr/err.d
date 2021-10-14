module purr.err;

import std.stdio;
import core.stdc.stdlib : exit;

void vmError(string src) {
    throw new Exception(src);
}

void vmFail(string src) {
    throw new Exception(src);
}
