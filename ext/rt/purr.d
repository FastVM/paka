module ext.rt.purr;

import purr.io;
import purr.base;
import purr.dynamic;
import ext.rt.bc;
import ext.rt.ast;

Pair[] libpurr() {
    Pair[] ret;
    ret.addLib("bc", lib2bc);
    ret.addLib("ir", lib2bc);
    ret.addLib("ast", lib2ast);
    return ret;
}