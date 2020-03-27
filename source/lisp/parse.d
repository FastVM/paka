module lisp.parse;
private import std.meta: AliasSeq;

alias NodeTypes = AliasSeq!(Call, String, Ident, Number);

class Node {}

class Call: Node {
    Node[] args;
    this(Node[] c) {
        args = c;
    }
    this(Node f, Node[] a) {
        args = f ~ a;
    }
    override string toString() {
        import std.conv: to;
        char[] ret;
        ret ~= "(";
        foreach (i, v; args) {
            if (i != 0) {
                ret ~= " ";
            }
            ret ~= v.to!string;
        }
        ret ~= ")";
        return cast(string) ret;
    }
}

class Atom: Node {
    string repr;
    this(string r) {
        repr = r;
    }
    override string toString() {
        return repr;
    }
}

class String: Atom {
    this(string s) {
        super(s);
    }
    override string toString() {
        return "\"" ~ repr ~ "\"";
    }
}

class Ident: Atom {
    this(string s) {
        super(s);
    }
}

class Number: Atom {
    this(string s) {
        super(s);
    }
    this(double d) {
        import std.conv: to;
        super(d.to!string);
    }
}

class Char: Atom {
    this(char c) {
        super([c]);
    }
}

private void strip(ref string code) {
    import std.algorithm: canFind;
    while (code.length > 0 && canFind(" \t\r\n", code[0])) {
        code.consume;
    }
}

private void consume(ref string code) {
    code = code[1..$];
}

private string parseIdent(ref string code) {
    import std.algorithm: canFind;
    char[] ret;
    while (!canFind(nonIdent, code[0])) {
        ret ~= code[0];
        code.consume;
    }
    return cast(string) ret;
}

private enum string nonIdent = "()[]{}#':\" \t\r\n";

Node parse(ref string code) {
    code.strip;
    scope(exit) {
        code.strip;
    }
    if (code[0] == '(') {
        code.consume;
        Node func = code.parse;
        Node[] args;
        while (code[0] != ')') {
            args ~= code.parse;
        }
        code.consume;
        return new Call(func, args);
    }
    if (code[0] == '"') {
        char[] ret;
        code.consume;
        while (code[0] != '"') {
            ret ~= code[0];
            code.consume;
        }
        code.consume;
        return new String(cast(string) ret);
    }
    return new Ident(code.parseIdent);
}
