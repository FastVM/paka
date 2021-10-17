module purr.ast.ast;

import std.algorithm;
import std.conv : to;
import std.meta;
import std.string;
import purr.err;
import purr.srcloc;

/// all possible node types
alias NodeTypes = AliasSeq!(Form, Value, Ident);

enum NodeKind {
    base,
    call,
    ident,
    value,
}

/// any node, not valid in the ast
class Node {
    Span span;

    NodeKind id() {
        return NodeKind.base;
    }
}

/// call of function or operator call
final class Form : Node {
    string form;
    Node[] args;

    Node getArg(T)(T n) {
        if (n < 0 || n >= args.length) {
            vmError("invalid ast");
            assert(false);
        } else {
            return args[n];
        }
    }

    Node[] sliceArg(T)(T n) {
        if (n < 0 || n >= args.length) {
            vmError("invalid ast");
            assert(false);
        } else {
            return args[n..$];
        }
    }

    Node[] sliceArg(T1, T2)(T1 n, T2 m) {
        if (n < 0 || n >= args.length || m < 1 || m > args.length || m + n > args.length) {
            vmError("invalid ast");
            assert(false);
        } else {
            return args[n..$-m];
        }
    }

    this(Args...)(string f, Args as) {
        static foreach (a; as) {
            args ~= a;
        }
        form = f;
    }

    override string toString() {
        char[] ret;
        ret ~= "(";
        ret ~= form;
        foreach (i, v; args) {
            ret ~= " ";
            ret ~= v.to!string;
        }
        ret ~= ")";
        return cast(string) ret;
    }

    override NodeKind id() {
        return NodeKind.call;
    }

    override bool opEquals(Object arg) {
        Form other = cast(Form) arg;
        if (other is null) {
            return false;
        }
        return form == other.form && args == other.args;
    }
}

size_t usedSyms;

Ident genSym() {
    usedSyms++;
    return new Ident("_purr_" ~ to!string(usedSyms - 1));
}

template ident(string name) {
    Ident value;

    static this() {
        value = new Ident(name);
    }

    Ident ident() {
        return new Ident(name);
    }
}

/// ident or number, detects at runtime
final class Ident : Node {
    string repr;

    this(string s) {
        repr = s;
    }

    override NodeKind id() {
        return NodeKind.ident;
    }

    override string toString() {
        return repr;
    }

    override bool opEquals(Object arg) {
        Ident other = cast(Ident) arg;
        if (other is null) {
            return false;
        }
        return repr == other.repr;
    }
}

final class Value : Node {
    void* value;
    TypeInfo info;

    this(T)(T v) {
        info = typeid(T);
        value = cast(void*)[v].ptr;
    }

    static Value empty() {
        return new Value(null);
    }

    override string toString() {
        if (info == typeid(double)) {
            return to!string(*cast(double*) value);
        }
        if (info == typeid(int)) {
            return to!string(*cast(int*) value);
        }
        if (info == typeid(bool)) {
            return to!string(*cast(bool*) value);
        }
        if (info == typeid(null)) {
            return "null";
        }
        if (info == typeid(string)) {
            return *cast(string*) value;
        }
        vmError("bad info");
        assert(false);
    }

    override NodeKind id() {
        return NodeKind.value;
    }

    override bool opEquals(Object arg) {
        Value other = cast(Value) arg;
        if (other is null) {
            return false;
        }
        return value == other.value;
    }
}
