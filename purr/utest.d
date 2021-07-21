module purr.utest;

bool ok(Err, T)(lazy T run) {
    bool okay;
    try {
        cast(void) run;
        okay = true;
    } catch (Err err) {
        okay = false;
    }
    return okay;
}

version (unittest) {
    void fail() {
        throw new Exception("oops");
    }

    void nofail() {
    }
}

unittest {
    assert(!ok!Exception(fail));
    assert(ok!Exception(nofail));
}
