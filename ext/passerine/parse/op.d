module ext.passerine.parse.op;

import purr.io;
import std.conv;
import purr.dynamic;
import purr.ast.ast;
import ext.passerine.parse.pattern;
import ext.passerine.parse.util;

UnaryOp parseUnaryOp(string[] ops)
{
    string opName = ops[0];
    if (opName == "-")
    {
        return (Node rhs) { return new Form("-", new Value(0), rhs); };
    }
    else if (opName == "..")
    {
        return (Node rhs) { return new Form("..", rhs); };
    }
    else
    {
        throw new Exception("parse error: not a unary operator: " ~ opName);
    }
}

BinaryOp parseBinaryOp(string[] ops)
{
    string opName = ops[0];
    switch (opName)
    {
    case "=":
        return (Node lhs, Node rhs) {
            if (Ident id = cast(Ident) lhs)
            {
                if (id.repr == "_")
                {
                    return rhs;
                }
                return new Form("set", id, rhs);
            }
            else if (Ident id = cast(Ident) rhs)
            {
                return new Form("assert", matcher(rhs, lhs), rhs);
            }
            else
            {
                Node sym = genSym;
                Node assign = new Form("set", sym, rhs);
                Node check = new Form("assert", matcher(sym, lhs), sym);
                return new Form("do", assign, check); 
            }
        };
    case "->":
        return (Node lhs, Node rhs) {
            Node[] args;
            Node cur = lhs;
            while (true)
            {
                if (Form call = cast(Form) cur)
                {
                    if (call.form == "call")
                    {
                        args ~= call.args[1];
                        cur = call.args[0];
                        continue;
                    }
                }
                args ~= cur;
                break;
            }
            Node ret = rhs;
            foreach (arg; args)
            {
                if (Ident id = cast(Ident) arg)
                {
                    ret = new Form("fun", new Form("args", new Ident(id.repr)), ret);
                }
                if (Value val = cast(Value) arg)
                {
                    Ident sym = genSym;
                    Node okCheck = new Form("==", [arg, sym]);
                    Node func = new Form("do", okCheck, ret);
                    ret = new Form("fun", new Form("args", new Ident(sym.repr)), func);
                }
                if (Form call = cast(Form) arg)
                {
                    Ident sym = genSym;
                    Node check = matcher(sym, arg);
                    Node func = new Form("do", check, ret);
                    ret = new Form("fun", new Form("args", new Ident(sym.repr)), func);
                }
            }
            return ret;
        };
    case ".":
        return (Node lhs, Node rhs) {
            return new Form("call", rhs, lhs);
        };
    case "and":
        return (Node lhs, Node rhs) {
            return new Form("&&", rhs, lhs);
        };
    case "or":
        return (Node lhs, Node rhs) {
            return new Form("||", rhs, lhs);
        };
    case "++":
        return (Node lhs, Node rhs) {
            return new Form("~", rhs, lhs);
        };
    default:
        return (Node lhs, Node rhs) {
            return new Form(opName, [lhs, rhs]);
        };
    }
}
