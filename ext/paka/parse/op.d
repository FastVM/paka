module paka.parse.op;

import purr.io;
import std.conv;
import purr.dynamic;
import purr.ast.ast;
import paka.built;
import paka.parse.util;

Node binaryFold(BinaryOp op, Node lhs, Node rhs)
{
    Node[] xy = [new Ident("_lhs"), new Ident("_rhs")];
    Node lambdaBody = op(xy[0], xy[1]);
    Call lambda = new Call(new Ident("@fun"), [new Call(xy), lambdaBody]);
    Call domap = new Call(new Value(native!metaFoldBinary), [lambda, lhs, rhs]);
    return domap;
}

Node unaryFold(BinaryOp op, Node rhs)
{
    Node[] xy = [new Ident("_lhs"), new Ident("_rhs")];
    Node lambdaBody = op(xy[0], xy[1]);
    Call lambda = new Call(new Ident("@fun"), [new Call(xy), lambdaBody]);
    Call domap = new Call(new Value(native!metaFoldUnary), [lambda, rhs]);
    return domap;
}

Node unaryDotmap(UnaryOp op, Node rhs)
{
    Node[] xy = [new Ident("_rhs")];
    Node lambdaBody = op(xy[0]);
    Call lambda = new Call(new Ident("@fun"), [new Call(xy), lambdaBody]);
    Call domap = new Call(new Value(native!metaMapPreParallel), [lambda, rhs]);
    return domap;
}

Node binaryDotmap(alias func)(BinaryOp op, Node lhs, Node rhs)
{
    Node[] xy = [new Ident("_lhs"), new Ident("_rhs")];
    Node lambdaBody = op(xy[0], xy[1]);
    Call lambda = new Call(new Ident("@fun"), [new Call(xy), lambdaBody]);
    Call domap = new Call(new Value(native!func), [lambda, lhs, rhs]);
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
            ops = ops[1 .. $];
        }
        else if (ops[0] == "\\")
        {
            ret ~= ops[0];
            ops = ops[1 .. $];
            slash++;
        }
        else
        {
            break;
        }
    }
    ret ~= ops[0];
    ops = ops[1 .. $];
    while (ops.length != 0)
    {
        if (ops[0] == ".")
        {
            ret ~= ops[0];
            ops = ops[1 .. $];
        }
        else if (ops[0] == "\\")
        {
            if (slash == 0)
            {
                break;
            }
            ret ~= ops[0];
            ops = ops[1 .. $];
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
            ops = rest[1 .. $];
            curUnary = (Node rhs) { return unaryFold(lastBinary, rhs); };
        }
        else
        {
            curUnary = parseUnaryOp([ops[0]]);
            ops = ops[1 .. $];
        }
        while (ops.length != 0)
        {
            if (ops[0] == ".")
            {
                UnaryOp lastUnary = curUnary;
                ops = ops[1 .. $];
                curUnary = (Node rhs) { return unaryDotmap(lastUnary, rhs); };
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
                return (Node rhs) { return curUnary(next(rhs)); };
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
        return (Node rhs) { return new Call(new Value(native!lengthOp), [rhs]); };
    }
    else if (opName == "not")
    {
        return (Node rhs) {
            return new Call(new Ident("!="), [rhs, new Value(true)]);
        };
    }
    else if (opName == "-")
    {
        throw new Exception("parse error: not a unary operator: " ~ opName
                ~ " (consider 0- instead)");
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
                return binaryDotmap!metaMapBothParallel(next, lhs, rhs);
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
                return binaryDotmap!metaMapLhsParallel(next, lhs, rhs);
            };
        }
        if (ops[$ - 1] == ".")
        {
            BinaryOp next = parseBinaryOp(ops[0 .. $ - 1]);
            return (Node lhs, Node rhs) {
                return binaryDotmap!metaMapRhsParallel(next, lhs, rhs);
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
    case "~=":
    case "-=":
    case "*=":
    case "/=":
    case "%=":
        throw new Exception("no operator assignment");
    default:
        if (opName == "|>")
        {
            return (Node lhs, Node rhs) {
                return new Call(new Ident("@rcall"), [lhs, rhs]);
            };
        }
        else if (opName == "to")
        {
            return (Node lhs, Node rhs) {
                return new Call(new Value(native!rangeOp), [lhs, rhs]);
            };
        }
        else if (opName == "<|")
        {
            return (Node lhs, Node rhs) {
                return new Call(new Ident("@call"), [lhs, rhs]);
            };
        }
        else
        {
            if (opName == "or")
            {
                opName = "||";
            }
            else if (opName == "and")
            {
                opName = "&&";
            }
            return (Node lhs, Node rhs) {
                return new Call(new Ident(opName), [lhs, rhs]);
            };
        }
    }
}
