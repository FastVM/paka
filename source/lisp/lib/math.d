module lisp.lib.math;

import lisp.dynamic: Dynamic, Array, dynamic;

Dynamic add(Array args) {
    double v = 0;
    foreach (i; args) {
        v += i.value.num;
    }
    return dynamic(v);
}

Dynamic sub(Array args) {
    double v = args[0].value.num;
    if (args.length == 1) {
        return dynamic(-v);
    }
    foreach (i; args[1..$]) {
        v -= i.value.num;
    }
    return dynamic(v);
}

Dynamic mul(Array args) {
    double v = 1;
    foreach (i; args) {
        v *= i.value.num;
    }
    return dynamic(v);
}

Dynamic div(Array args) {
    double v = args[0].value.num;
    if (args.length == 1) {
        return dynamic(1/v);
    }
    foreach (i; args[1..$]) {
        v /= i.value.num;
    }
    return dynamic(v);
}
