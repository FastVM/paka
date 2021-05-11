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
    if (opName == "..")
    {
        return (Node rhs) { return new Form("..", rhs); };
    }
    else
    {
        throw new Exception("parse error: not a unary operator: " ~ opName);
    }
}

Dynamic check2(Dynamic[] args)
{
    if (args[0] != args[1])
    {
        throw new Exception("assign error: " ~ args[0].to!string ~ " = " ~ args[1].to!string);
    }
    return args[1];
}

Dynamic checkTrue(Dynamic[] args)
{
    if (!args[0].value.log)
    {
        throw new Exception("assign error: bad value: " ~ args[1].to!string);
    }
    return args[1];
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
            else
            {
                Node sym = genSym;
                Node assign = new Form("set", sym, rhs);
                Node check = new Form("call", new Value(native!checkTrue), [matcher(sym, lhs), sym]);
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
                    if (Ident id = cast(Ident) call.args[0])
                    {
                        if (id.repr == "call")
                        {
                            args ~= call.args[2];
                            cur = call.args[1];
                            continue;
                        }
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
                    Node okCheck = new Form("call", new Value(native!check2), [arg, sym]);
                    Node func = new Form("do", okCheck, ret);
                    ret = new Form("fun", new Form("args", new Ident(sym.repr)), func);
                }
                if (Form call = cast(Form) arg)
                {
                    Ident sym = genSym;
                    Node check = new Form("call", new Value(native!checkTrue), [matcher(sym, arg), sym]);
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
    default:
        return (Node lhs, Node rhs) {
            return new Form(opName, [lhs, rhs]);
        };
    }
}
