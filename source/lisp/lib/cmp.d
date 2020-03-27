module lisp.lib.cmp;

import lisp.dynamic: Dynamic, Array;

Dynamic cmp(string op)(Array arr) {
    import lisp.dynamic: ltrue, lfalse;
    double val = arr[0].value.num;
    foreach (i; arr[1..$]) {
        double cur = i.value.num;
        if (mixin("val" ~ op ~ "cur")) {
            val = cur;
        }
        else {
            return lfalse;
        }
    }
    return ltrue;
}

Dynamic equal(Array arr) {
    import lisp.dynamic: ltrue, lfalse;
    foreach (i; 0..arr.length-1) {
        foreach (j; i+1..arr.length) {
            if (arr[i] != arr[j]) {
                return lfalse;
            }
        }
    }
    return ltrue;
}

Dynamic notEqual(Array arr) {
    import lisp.dynamic: ltrue, lfalse;
    foreach (i; 0..arr.length-1) {
        foreach (j; i+1..arr.length) {
            if (arr[i] == arr[j]) {
                return lfalse;
            }
        }
    }
    return ltrue;
}

alias lt = cmp!"<";
alias gt = cmp!">";
alias lte = cmp!"<=";
alias gte = cmp!">=";
