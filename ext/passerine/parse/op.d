module passerine.parse.op;

import purr.io;
import std.conv;
import purr.dynamic;
import purr.ast.ast;
import passerine.parse.util;

UnaryOp parseUnaryOp(string[] ops)
{
    string opName = ops[0];
    if (opName == "-")
    {
        return (Node rhs) { return new Call(new Ident("-"), [new Ident("0"), rhs]); };
    }
    else
    {
        throw new Exception("parse error: not a unary operator: " ~ opName);
    }
}

Dynamic check(Dynamic[] args)
{
    if (args[0] != args[1])
    {
        throw new Exception("assign error: " ~ args[0].to!string ~ " = " ~ args[1].to!string);
    }
    return args[1];
}

Node doAssign(Node lhs, Node rhs)
{
    if (Ident lhsv = cast(Ident) lhs)
    {
        if (lhsv.repr == "_")
        {
            return rhs;
        }
        return new Call(new Ident("@set"), [lhs, rhs]);
    }
    else if (Value lhsv = cast(Value) lhs)
    {
        return new Call(new Value(native!check), [lhs, rhs]);
    }
    Call call = cast(Call) lhs;
    assert(call, "compiler got to illegal state");
    if (Ident id = cast(Ident) call.args[0])
    {
        switch (id.repr)
        {
        default:
            break;
        case "@array":
            Node[] ret;
            Ident sym = genSym;
            foreach (index, arg; call.args[1 .. $])
            {
                ret ~= doAssign(arg, new Call(new Ident("@index"), [
                            sym, new Value(index)
                        ]));
            }
            Node val = new Call(new Ident("@set"), [sym, rhs]);
            return new Call(new Ident("@do"), val ~ ret ~ sym);
        }
    }
    return new Call(new Value(native!check), [lhs, rhs]);
}

BinaryOp parseBinaryOp(string[] ops)
{
    string opName = ops[0];
    switch (opName)
    {
    case "=":
        return (rhs, lhs) => doAssign(rhs, lhs);
    case "->":
        return (Node lhs, Node rhs) {
            Node[] args;
            Node cur = lhs;
            while (true)
            {
                if (Call call = cast(Call) cur)
                {
                    if (Ident id = cast(Ident) call.args[0])
                    {
                        if (id.repr == "@call")
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
                    ret = new Call(new Ident("@fun"), [new Call([id]), ret]);
                }
                if (Value val = cast(Value) arg)
                {
                    Node sym = genSym;
                    Node okCheck = new Call(new Value(native!check), [arg, sym]);
                    Node func = new Call(new Ident("@do"), [okCheck, ret]);
                    ret = new Call(new Ident("@fun"), [new Call([sym]), func]);
                }
                if (Call call = cast(Call) arg)
                {
                    Node sym = genSym;
                    Node func = new Call(new Ident("@do"), [doAssign(arg, sym), ret]);
                    ret = new Call(new Ident("@fun"), [new Call([sym]), func]);
                }
            }
            return ret;
        };
    case ".":
        return (Node lhs, Node rhs) {
            return new Call(new Ident("@call"), [rhs, lhs]);
        };
    default:
        return (Node lhs, Node rhs) {
            return new Call(new Ident(opName), [lhs, rhs]);
        };
    }
}
