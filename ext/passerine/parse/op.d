module ext.passerine.parse.op;

import std.conv;
import purr.err;
import purr.ast.ast;
import ext.passerine.parse.util;

UnaryOp parseUnaryOp(string[] ops) {
    string opName = ops[0];
    if (opName == "-") {
        return (Node rhs) { return new Form("-", new Value(0L), rhs); };
    }
    if (opName == "..") {
        return (Node rhs) { return new Form("..", rhs); };
    } else {
        throw new Exception("parse error: not a unary operator: " ~ opName);
    }
}

BinaryOp parseBinaryOp(string[] ops) {
    string opName = ops[0];
    switch (opName) {
    case "=":
        return (Node lhs, Node rhs) {
            if (Ident id = cast(Ident) lhs) {
                if (id.repr == "_") {
                    return rhs;
                }
                return new Form("var", id, rhs);
            } else {
                vmError("assign to bad value");
                assert(false);
            }
        };
    case "->":
        return (Node lhs, Node rhs) {
            Node[] args;
            Node cur = lhs;
            while (true) {
                if (Form call = cast(Form) cur) {
                    if (call.form == "call") {
                        args ~= call.args[1];
                        cur = call.args[0];
                        continue;
                    }
                }
                args ~= cur;
                break;
            }
            Node ret = rhs;
            foreach (arg; args) {
                if (Ident id = cast(Ident) arg) {
                    ret = new Form("lambda", new Form("args", new Ident(id.repr)), ret);
                } else {
                    vmError("cannot unpack yet");
                assert(false);
                }
            }
            return ret;
        };
    case ".":
        return (Node lhs, Node rhs) { return new Form("call", rhs, lhs); };
    case "and":
        return (Node lhs, Node rhs) { return new Form("&&", rhs, lhs); };
    case "or":
        return (Node lhs, Node rhs) { return new Form("||", rhs, lhs); };
    case "++":
        return (Node lhs, Node rhs) { return new Form("~", rhs, lhs); };
    default:
        return (Node lhs, Node rhs) { return new Form(opName, [lhs, rhs]); };
    }
}
