module passerine.parse.op;

import purr.io;
import std.conv;
import purr.dynamic;
import purr.ast.ast;
import passerine.parse.util;

string[] readBinaryOp(ref string[] ops)
{
    size_t slash;
    string[] ret;
    while (ops.length >= 2)
    {
        if (ops[0] == ".")
        {
            ret ~= ops[0];
            ops = ops[1..$];
        }
        else if (ops[0] == "\\")
        {
            ret ~= ops[0];
            ops = ops[1..$];
            slash++;
        }
        else {
            break;
        }
    }
    ret ~= ops[0];
    ops = ops[1..$];
    while (ops.length != 0)
    {
        if (ops[0] == ".")
        {
            ret ~= ops[0];
            ops = ops[1..$];
        }
        else if (ops[0] == "\\")
        {
            if (slash == 0) {
                break;
            }
            ret ~= ops[0];
            ops = ops[1..$];
            slash--;
        }
        else
        {
            break;
        }
    }
    return ret;
}

UnaryOp parseUnaryOp(string[] ops)
{
    string opName = ops[0];
    if (opName == "-")
    {
        return (Node rhs) {
            return new Call(new Ident("-"), [new Ident("0"), rhs]);
        };
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
            return new Call(new Ident("@set"), [lhs, rhs]);
        };
    case "->":
        return (Node lhs, Node rhs) {
            if (Call call = cast(Call) lhs)
            {
                return new Call(new Ident("@fun"), [new Call(call.args[1..$]), rhs]);
            }
            else
            {
                return new Call(new Ident("@fun"), [new Call([lhs]), rhs]);
            }
        };
    default:
        return (Node lhs, Node rhs) {
            return new Call(new Ident(opName), [lhs, rhs]);
        };
    }
}
