module lisp.base;

private import lisp.dynamic: Dynamic;
private import lisp.bytecode: Function;

Dynamic[string] getRootBase() {
    import lisp.lib.io, lisp.lib.cmp, lisp.lib.math;
    import lisp.dynamic: Array, dynamic;
    Dynamic load(Dynamic function(Array args) fn) {
        return dynamic(fn);
    }
    return [
        "print": load(&lisp.lib.io.print),
        "<": load(&lisp.lib.cmp.lt),
        ">": load(&lisp.lib.cmp.gt),
        "<=": load(&lisp.lib.cmp.lte),
        ">=": load(&lisp.lib.cmp.gte),
        "eq?": load(&lisp.lib.cmp.equal),
        "not-eq?": load(&lisp.lib.cmp.notEqual),
        "+": load(&lisp.lib.math.add),
        "-": load(&lisp.lib.math.sub),
        "*": load(&lisp.lib.math.mul),
        "/": load(&lisp.lib.math.div),
    ];
}

Function baseFunction() {
    Function ret = new Function;
    ushort[string] byName;
    foreach (i; getRootBase.byKey) {
        byName[i] = cast(ushort) byName.length;
    }
    string[] byPlace = ["print"];
    ret.stab = Function.Lookup(byName, byPlace);
    return ret;
}

Dynamic* loadBase() {
    return getRootBase.values.ptr;
}
