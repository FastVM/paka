module ext.paka.parse.op;

import std.conv : to;
import purr.err;
import purr.ast.ast;
import std.algorithm;
import ext.paka.parse.util;

enum string[] setMutOps = ["+=", "*=", "/=", "-=", "%="];

UnaryOp parseUnaryOp(string[] ops) {
    if (ops.length > 1) {
        UnaryOp now = parseUnaryOp([ops[0]]);
        UnaryOp next = ops[1 .. $].parseUnaryOp();
        return (Node rhs) { return now(next(rhs)); };
    }
    string opName = ops[0];
    if (opName == "#") {
        return (Node rhs) { return new Form("length", [rhs]); };
    } else if (opName == "not") {
        return (Node rhs) { return new Form("not", rhs); };
    } else if (opName == "-") {
        vmFail("parse error: not a unary operator: " ~ opName ~ " (consider 0- instead)");
    } else {
        vmFail("parse error: not a unary operator: " ~ opName);
    }
    assert(false);
}

Node call(Node fun, Node[] args) {
    if (Ident id = cast(Ident) fun) {
        if (id.repr == "length") {
            return new Form("length", args);
        }
        if (id.repr == "putchar") {
            return new Form("putchar", args);
        }
        if (id.repr == "type") {
            return new Form("type", args);
        }
    }
    return new Form("call", fun, args);
}

BinaryOp parseBinaryOp(string[] ops) {
    if (ops.length == 1) {
        string opName = ops[0];
        switch (opName) {
        case ":=":
            return (Node lhs, Node rhs) {
                if (Form lhsForm = cast(Form) lhs) {
                    if (lhsForm.form == "call") {
                        Node rhsLambda = new Form("lambda", new Form("args",
                                lhsForm.args[1 .. $]), rhs);
                        return parseBinaryOp([":="])(lhsForm.args[0], rhsLambda);
                    }
                    if (lhsForm.form == "index") {
                        vmFail("do not use := for setting array index"); 
                        assert(false);
                    }
                    vmFail("assign to expression of type: " ~ lhsForm.form);
                    assert(false);
                } else {
                    return new Form("var", lhs, rhs);
                }
            };
        case "=":
            return (Node lhs, Node rhs) {
                if (Form lhsForm = cast(Form) lhs) {
                    if (lhsForm.form == "call") {
                        Node rhsLambda = new Form("lambda", new Form("args",
                                lhsForm.args[1 .. $]), rhs);
                        return parseBinaryOp(["="])(lhsForm.args[0], rhsLambda);
                    }
                    if (lhsForm.form == "index" || lhsForm.form == "unbox") {
                        return new Form("set", lhs, rhs);
                    }
                    vmFail("assign to expression of type: " ~ lhsForm.form);
                    assert(false);
                } else {
                    return new Form("set", lhs, rhs);
                }
            };
        default:
            if (setMutOps.canFind(opName)) {
                return (Node lhs, Node rhs) {
                    Node src = parseBinaryOp([opName[0 .. $ - 1]])(lhs, rhs);
                    return parseBinaryOp(["="])(lhs, src);
                };
            } else if (opName == "|>") {
                return (Node lhs, Node rhs) { return rhs.call([lhs]); };
            } else if (opName == "<|") {
                return (Node lhs, Node rhs) { return lhs.call([rhs]); };
            } else {
                if (opName == "or") {
                    opName = "||";
                } else if (opName == "and") {
                    opName = "&&";
                }
                return (Node lhs, Node rhs) { return new Form(opName, [lhs, rhs]); };
            }
        }
    } else {
        vmFail("no multi ops yet");
        assert(false);
    }
}
