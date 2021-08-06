module ext.paka.parse.op;

import std.conv : to;
import purr.err;
import purr.ast.ast;
import ext.paka.parse.util;

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
        vmError("parse error: not a unary operator: " ~ opName ~ " (consider 0- instead)");
    } else {
        vmError("parse error: not a unary operator: " ~ opName);
    }
    assert(false);
}

Node call(Node fun, Node[] args) {
    return new Form("call", fun, args);
}

BinaryOp parseBinaryOp(string[] ops) {
    assert(ops.length == 1);
    string opName = ops[0];
    switch (opName) {
    case "=":
        return (Node lhs, Node rhs) {
            if (Form lhsForm = cast(Form) lhs) {
                if (lhsForm.form == "call") {
                    Node rhsLambda = new Form("lambda", new Form("args", lhsForm.args[1 .. $]), rhs);
                    return parseBinaryOp(["="])(lhsForm.args[0], rhsLambda);
                }
                vmError("assign to expression of type: " ~ lhsForm.form);
                assert(false);
            } else {
                return new Form("set", lhs, rhs);
            }
        };
    default:
        if (opName[$ - 1] == '=') {
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
}
