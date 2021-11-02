module purr.err;

import core.stdc.stdlib : exit;

class Problem : Exception {
    this(Types...)(Types args) {
        super(args);
    }
}

class Recover : Problem {
    this(Types...)(Types args) {
        super(args);
    }
}

void vmCheckError(bool cond, lazy string src) {
    if (!cond) {
        vmError(src);
    }
}

void vmError(string src) {
    throw new Problem(src);
}

void vmFail(string src) {
    throw new Recover(src);
}
