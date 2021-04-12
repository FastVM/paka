module ext.paka.parse.op;

import purr.io;
import std.conv;
import purr.ast.ast;
import paka.parse.util;

Node binaryFold(BinaryOp op, Node lhs, Node rhs)
{
    Node[] xy = [new Ident("_lhs"), new Ident("_rhs")];
    Node lambdaBody = op(xy[0], xy[1]);
    Call lambda = new Call(new Ident("@fun"), [new Call(xy), lambdaBody]);
    Call domap = new Call(new Ident("_paka_fold_binary"), [lambda, lhs, rhs]);
    return domap;
}

Node unaryFold(BinaryOp op, Node rhs)
{
    Node[] xy = [new Ident("_lhs"), new Ident("_rhs")];
    Node lambdaBody = op(xy[0], xy[1]);
    Call lambda = new Call(new Ident("@fun"), [new Call(xy), lambdaBody]);
    Call domap = new Call(new Ident("_paka_fold_unary"), [lambda, rhs]);
    return domap;
}

Node unaryDotmap(UnaryOp op, Node rhs)
{
    Node[] xy = [new Ident("_rhs")];
    Node lambdaBody = op(xy[0]);
    Call lambda = new Call(new Ident("@fun"), [new Call(xy), lambdaBody]);
    Call domap = new Call(new Ident("_paka_map_pre"), [lambda, rhs]);
    return domap;
}

Node binaryDotmap(string s)(BinaryOp op, Node lhs, Node rhs)
{
    Node[] xy = [new Ident("_lhs"), new Ident("_rhs")];
    Node lambdaBody = op(xy[0], xy[1]);
    Call lambda = new Call(new Ident("@fun"), [new Call(xy), lambdaBody]);
    Call domap = new Call(new Ident(s), [lambda, lhs, rhs]);
    return domap;
}

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
    if (ops.length > 1)
    {
        string[] rest = ops;
        BinaryOp lastBinary = parseBinaryOp(rest.readBinaryOp);
        UnaryOp curUnary = void;
        if (rest.length != 0 && rest[0] == "\\")
        {
            ops = rest[1..$];
            curUnary = (Node rhs) {
                return unaryFold(lastBinary, rhs);
            };
        }
        else {
            curUnary = parseUnaryOp([ops[0]]);
            ops = ops[1..$];
        }
        while (ops.length != 0)
        {
            if (ops[0] == ".")
            {
                UnaryOp lastUnary = curUnary;
                ops = ops[1..$];
                curUnary = (Node rhs) {
                    return unaryDotmap(lastUnary, rhs);
                };
            }
            else if (ops[0] == "\\")
            {
                throw new Exception("parse error: double unary fold is dissallowed");
            }
            else
            {
                break;
            }
        }
        if (ops.length != 0)
        {
            rest = ops.readBinaryOp;
            if (rest.length == 0)
            {
                UnaryOp next = ops.parseUnaryOp();
                return (Node rhs) {
                    return curUnary(next(rhs));
                };
            }
            else
            {
                BinaryOp curBinary = rest.parseBinaryOp;
                UnaryOp nextUnary = ops.parseUnaryOp();
                return (Node rhs) {
                    Node tmp = new Call(new Ident("@set"), [genSym, rhs]);
                    Node res = curBinary(curUnary(tmp), nextUnary(tmp));
                    return new Call(new Ident("@do"), [tmp, res]);
                };
            }
        }
        return curUnary;
    }
    string opName = ops[0];
    if (opName == "#")
    {
        return (Node rhs)
        {
            return new Call(new Ident("_paka_length"), [rhs]);
        };
    }
    else if (opName == "-")
    {
        throw new Exception(
                "parse error: not a unary operator: " ~ opName ~ " (consider 0- instead)");
    }
    else
    {
        throw new Exception("parse error: not a unary operator: " ~ opName);
    }
}

BinaryOp parseBinaryOp(string[] ops)
{
    if (ops.length > 1)
    {
        if (ops[0] == "." && ops[$ - 1] == ".")
        {
            BinaryOp next = parseBinaryOp(ops[1 .. $ - 1]);
            return (Node lhs, Node rhs) {
                return binaryDotmap!"_paka_map_both"(next, lhs, rhs);
            };
        }
        if (ops[0] == "\\" && ops[$ - 1] == "\\")
        {
            BinaryOp next = parseBinaryOp(ops[1 .. $ - 1]);
            return (Node lhs, Node rhs) { return binaryFold(next, lhs, rhs); };
        }
        if (ops[0] == ".")
        {
            BinaryOp next = parseBinaryOp(ops[1 .. $]);
            return (Node lhs, Node rhs) {
                return binaryDotmap!"_paka_map_lhs"(next, lhs, rhs);
            };
        }
        if (ops[$ - 1] == ".")
        {
            BinaryOp next = parseBinaryOp(ops[0 .. $ - 1]);
            return (Node lhs, Node rhs) {
                return binaryDotmap!"_paka_map_rhs"(next, lhs, rhs);
            };
        }
        assert(false);
    }
    string opName = ops[0];
    switch (opName)
    {
    case "=":
        return (Node lhs, Node rhs) {
            return new Call(new Ident("@set"), [lhs, rhs]);
        };
    case "+=":
        return (Node lhs, Node rhs) {
            return new Call(new Ident("@opset"), [
                    cast(Node) new Ident("add"), lhs, rhs
                    ]);
        };
    case "~=":
        return (Node lhs, Node rhs) {
            return new Call(new Ident("@opset"), [
                    cast(Node) new Ident("cat"), lhs, rhs
                    ]);
        };
    case "-=":
        return (Node lhs, Node rhs) {
            return new Call(new Ident("@opset"), [
                    cast(Node) new Ident("sub"), lhs, rhs
                    ]);
        };
    case "*=":
        return (Node lhs, Node rhs) {
            return new Call(new Ident("@opset"), [
                    cast(Node) new Ident("mul"), lhs, rhs
                    ]);
        };
    case "/=":
        return (Node lhs, Node rhs) {
            return new Call(new Ident("@opset"), [
                    cast(Node) new Ident("div"), lhs, rhs
                    ]);
        };
    case "%=":
        return (Node lhs, Node rhs) {
            return new Call(new Ident("@opset"), [
                    cast(Node) new Ident("mod"), lhs, rhs
                    ]);
        };
    default:
        if (opName == "|>")
        {
            return (Node lhs, Node rhs) {
                return new Call(new Ident("@rcall"), [lhs, rhs]);
            };
        }
        else if (opName == "->")
        {
            return (Node lhs, Node rhs) {
                return new Call(new Ident("_paka_range"), [lhs, rhs]);
            };
        }
        else if (opName == "<|")
        {
            return (Node lhs, Node rhs) {
                return new Call(new Ident("@call"), [lhs, rhs]);
            };
        }
        else if (opName == "=>")
        {
            return (Node lhs, Node rhs) {
                return new Call(new Ident("@call"), [new Call([lhs]), rhs]);
            };
        }
        else
        {
            return (Node lhs, Node rhs) {
                return new Call(new Ident(opName), [lhs, rhs]);
            };
        }
    }
}