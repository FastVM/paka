module purr.type.err;

import purr.type.repr;
import purr.ast.ast;
import purr.srcloc;

import std.stdio;

class FailedTypeCheck : Exception {
    this() {
        super("Internal Error");
    }
}

class FailedCheck : FailedTypeCheck {
    Type[] wants;
    Type has;

    this(Type h, Type[] w) {
        super();
        has = h;
        wants = w;
    }
}

enum string nameToOp(string name) {
    final switch (name) {
    case "add" : return "+";
    case "sub" : return "-";
    case "mul" : return "*";
    case "div" : return "/";
    case "mod" : return "%";
    case "lt" : return "<";
    case "gt" : return ">";
    case "lte" : return "<=";
    case "gte" : return ">=";
    case "eq" : return "eq";
    case "neq" : return "!=";
    case "neg" : return ".";
    case "index" : return ".";
    }
}

class FailedBinaryOperator(string name) : FailedCheck {
    enum string op = nameToOp(name);

    this(Type h, Type[] w) {
        super(h, w);
    }
}

class FailedBinaryOperatorLeft(string name) : FailedBinaryOperator!name {
    Type rhs;

    this(Type h, Type[] w, Type r) {
        rhs = r;
        super(h, w);
    }
}

class FailedBinaryOperatorRight(string name) : FailedBinaryOperator!name {
    Type lhs;

    this(Type h, Type[] w, Type l) {
        super(h, w);
        lhs = l;
    }
}

class FailedBinaryOperatorArms(string name) : FailedTypeCheck {
    string op = nameToOp(name);
    Type lhs;
    Type rhs;

    this(Type l, Type r) {
        super();
        lhs = l;
        rhs = r;
    }
}
