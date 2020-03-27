module lisp.dynamic;

private import std.functional: memoize;

alias Array = Dynamic[];
alias Table = Dynamic[Dynamic];

Dynamic dynamicImpl(T)(T v) {
    return Dynamic(v);
}

Dynamic dynamic(T)(T v) if (true) {
    return dynamicImpl(v);
}

Dynamic dynamic(T)(T v) if (false) {
    return memoize!(dynamicImpl!T)(v);
}

Dynamic nil;
Dynamic ltrue;
Dynamic lfalse;
static this() {
    nil = Dynamic.init;
    lfalse = Dynamic(false);
    ltrue = Dynamic(true);
}

struct Dynamic {
    import lisp.bytecode: Function;
    enum Type: ubyte {
        nil,
        log,
        num,
        str,
        arr,
        tab,
        fun,
        del,
        pro,
    }
    union Value {
        bool log;
        double num;
        string* str;
        Array* arr;
        Table tab;
        union Callable {
            Dynamic function(Array) fun;
            Dynamic delegate(Array)* del;
            Function pro;
        }
        Callable fun;
    }
    align(1):
    Type type;
    Value value;
    this(bool log) {
        value.log = log;
        type = Type.log;
    }
    this(double num) {
        value.num = num;
        type = Type.num;
    }
    this(string str) {
        value.str = [str].ptr;
        type = Type.str;
    }
    this(Array arr) {
        value.arr = [arr].ptr;
        type = Type.arr;
    }
    this(Table tab) {
        value.tab = tab;
        type = Type.tab;
    }
    this(Dynamic function(Array) fun) {
        value.fun.fun = fun;
        type = Type.fun;
    }
    this(Dynamic delegate(Array) del) {
        value.fun.del = [del].ptr;
        type = Type.del;
    }
    this(Function pro) {
        value.fun.pro = pro;
        type = Type.pro;
    }
    string toString() {
        return this.strFormat;
    }
    Dynamic opCall(Dynamic[] args) {
        import lisp.vm: run;
        switch(type) {
        case Type.fun:
            return value.fun.fun(args);
        case Type.del:
            return (*value.fun.del)(args);
        case Type.pro:
            return run(value.fun.pro, args);
        default:
            throw new Exception("Type error: not a function");
        }
    }
}

private string strFormat(Dynamic dyn, Dynamic[] before=null) {
    import std.conv: to;
    import std.algorithm: canFind;
    if (canFind(before, dyn)) {
        return "...";
    }
    before ~= dyn;
    scope(exit) {
        before.length--;
    }
    final switch (dyn.type) {
    case Dynamic.Type.nil:
        return "nil";
    case Dynamic.Type.log:
        return dyn.value.log.to!string;
    case Dynamic.Type.num:
        return dyn.value.num.to!string;
    case Dynamic.Type.str:
        return *dyn.value.str;
    case Dynamic.Type.arr:
        char[] ret;
        ret ~= "(list";
        foreach (i; *dyn.value.arr) {
            ret ~= " ";
            ret ~= strFormat(i, before);
        }
        ret ~= ")";
        return cast(string) ret;
    case Dynamic.Type.tab:
        char[] ret;
        ret ~= "(table";
        foreach (i; dyn.value.tab.byKeyValue) {
            ret ~= " ";
            ret ~= strFormat(i.key, before);
            ret ~= " ";
            ret ~= strFormat(i.value, before);
        }
        ret ~= ")";
        return cast(string) ret;
    case Dynamic.Type.fun:
        return dyn.value.fun.fun.to!string;
    case Dynamic.Type.del:
        return dyn.value.fun.del.to!string;
    case Dynamic.Type.pro:
        return dyn.value.fun.pro.to!string;
    }
}
