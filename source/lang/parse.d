module lang.parse;

import lang.ast;
import lang.tokens;
import lang.data.array;
import std.stdio;
import std.algorithm;

enum string[] cmpOps = ["<", ">", "<=", ">=", "==", "!="];

SafeArray!Node readOpen(string v)(ref SafeArray!Token tokens) if (v != "{}")
{
    SafeArray!Node args;
    tokens = tokens[1 .. $];
    while (!tokens[0].isClose([v[1]]))
    {
        args ~= tokens.readExpr;
        if (tokens[0].isComma)
        {
            tokens = tokens[1 .. $];
        }
    }
    tokens = tokens[1 .. $];
    return args;
}

SafeArray!Node readOpen(string v)(ref SafeArray!Token tokens) if (v == "{}")
{
    SafeArray!Node args;
    tokens = tokens[1 .. $];
    size_t items = 0;
    while (!tokens[0].isClose([v[1]]))
    {
        args ~= tokens.readExpr;
        items++;
        if ((items % 2 == 0 && tokens[0].isComma) || (items % 2 == 1 && tokens[0].isOperator(":")))
        {
            tokens = tokens[1 .. $];
        }
    }
    tokens = tokens[1 .. $];
    return args;
}

alias readParens = readOpen!"()";
alias readSquare = readOpen!"[]";
alias readBrace = readOpen!"{}";

Node readPostExtend(ref SafeArray!Token tokens, Node last)
{
    if (tokens.length == 0)
    {
        return last;
    }
    Node ret = void;
    if (tokens[0].isOpen("("))
    {
        ret = new Call(last, tokens.readParens);
    }
    else if (tokens[0].isOpen("["))
    {
        ret = new Call(new Ident("@index"), last ~ tokens.readSquare);
    }
    else if (tokens[0].isOperator("."))
    {
        tokens = tokens[1 .. $];
        ret = new Call(new Ident("@index"), [last, new String(tokens[0].value)]);
        tokens = tokens[1 .. $];
    }
    else if (tokens[0].isOperator("::"))
    {
        tokens = tokens[1 .. $];
        ret = new Call(new Ident("@method"), [last, new String(tokens[0].value)]);
        tokens = tokens[1 .. $];
    }
    else
    {
        throw new Exception("parser: invalid parse");
    }
    return tokens.readPostExtend(ret);
}

Node readIf(ref SafeArray!Token tokens)
{
    SafeArray!Node cond = tokens.readParens;
    if (cond.length != 1)
    {
        throw new Exception("parser: if takes one");
    }
    Node iftrue = tokens.readBlock;
    Node iffalse;
    if (tokens.length > 0 && tokens[0].isKeyword("else"))
    {
        tokens = tokens[1 .. $];
        iffalse = tokens.readBlock;
    }
    else
    {
        iffalse = new Ident("@nil");
    }
    return new Call(new Ident("@if"), [cond[0], iftrue, iffalse]);
}

Node readUsing(ref SafeArray!Token tokens)
{
    SafeArray!Node obj = tokens.readParens;
    if (obj.length != 1)
    {
        throw new Exception("invalid parse");
    }
    Node bod = tokens.readBlock;
    return new Call(new Ident("@using"), [obj[0], bod]);
}

Node readTableCons(ref SafeArray!Token tokens)
{
    Node bod = tokens.readBlock;
    return new Call(new Ident("@using"), [new Call(new Ident("@table"), []), bod]);
}

Node readPostExpr(ref SafeArray!Token tokens)
{
    Node last = void;
    if (tokens[0].isKeyword("target"))
    {
        tokens = tokens[1 .. $];
        last = new Call(new Ident("@target"), [tokens.readPostExpr]);
    }
    else if (tokens[0].isKeyword("lambda"))
    {
        tokens = tokens[1 .. $];
        if (tokens[0].isOpen("("))
        {
            last = new Call(new Ident("@fun"), [
                    new Call(tokens.readParens), tokens.readBlock
                    ]);
        }
        else if (tokens[0].isOpen("{"))
        {
            last = new Call(new Ident("@fun"), [new Call([]), tokens.readBlock]);
        }
    }
    else if (tokens[0].isOpen("("))
    {
        last = new Call(new Ident("@do"), tokens.readParens);
    }
    else if (tokens[0].isOpen("["))
    {
        last = new Call(new Ident("@array"), tokens.readSquare);
    }
    else if (tokens[0].isOpen("{"))
    {
        last = new Call(new Ident("@table"), tokens.readBrace);
    }
    else if (tokens[0].isKeyword("if"))
    {
        tokens = tokens[1 .. $];
        last = tokens.readIf;
    }
    else if (tokens[0].isKeyword("using"))
    {
        tokens = tokens[1 .. $];
        last = tokens.readUsing;
    }
    else if (tokens[0].isKeyword("table"))
    {
        tokens = tokens[1 .. $];
        last = tokens.readTableCons;
    }
    else if (tokens[0].isKeyword("while"))
    {
        tokens = tokens[1 .. $];
        Node cond = tokens.readParens[$ - 1];
        Node loop = tokens.readBlock;
        last = new Call(new Ident("@while"), [cond, loop]);
    }
    else if (tokens[0].isIdent)
    {
        last = new Ident(tokens[0].value);
        tokens = tokens[1 .. $];
    }
    else if (tokens[0].isString)
    {
        last = new String(tokens[0].value);
        tokens = tokens[1 .. $];
    }
    return tokens.readPostExtend(last);
}

Node readPreExpr(ref SafeArray!Token tokens)
{
    if (tokens[0].isOperator)
    {
        Token op = tokens[0];
        tokens = tokens[1 .. $];
        string val = op.value;
        if (op.value == "*")
        {
            val = "...";
        }
        return new Call(new Ident(val), [tokens.readPreExpr]);
    }
    return tokens.readPostExpr;
}

Node readExpr(ref SafeArray!Token tokens, size_t level = 0)
{
    if (level == prec.length)
    {
        return tokens.readPreExpr;
    }
    SafeArray!Token[] sub = [SafeArray!Token.init];
    SafeArray!Token opers;
    bool lastIsOp = true;
    size_t depth = 0;
    while (tokens.length != 0)
    {
        Token token = tokens[0];
        bool found = false;
        if (token.isOpen)
        {
            depth++;
        }
        if (token.isClose)
        {
            if (depth == 0)
            {
                break;
            }
            depth--;
        }
        if (depth == 0)
        {
            if (token.isComma || token.isSemicolon || token.isOperator(":"))
            {
                break;
            }
            foreach (op; prec[level])
            {
                if (token.isOperator(op) && !lastIsOp)
                {
                    sub.length++;
                    opers ~= token;
                    found = true;
                    break;
                }
            }
        }
        if (!found)
        {
            sub[$ - 1] ~= token;
        }
        lastIsOp = token.isOperator;
        tokens = tokens[1 .. $];
    }
    if (opers.length > 0 && opers[0].isOperator("=>"))
    {
        Node ret = sub[$ - 1].readExpr(level + 1);
        foreach_reverse (v; sub[0 .. $ - 1])
        {
            if (v[0].isOpen("("))
            {
                ret = new Call(new Ident("=>"), [new Call(v.readParens), ret]);
            }
            else
            {
                ret = new Call(new Ident("=>"), [v.readExpr(level + 1), ret]);
            }
        }
        return ret;
    }
    Node ret = sub[0].readExpr(level + 1);
    foreach (i, v; opers)
    {
        switch (v.value)
        {
        case "=":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@set"), [ret, rhs]);
            break;
        case "+=":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@opset"), [new Ident("add"), ret, rhs]);
            break;
        case "-=":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@opset"), [new Ident("sub"), ret, rhs]);
            break;
        case "*=":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@opset"), [new Ident("mul"), ret, rhs]);
            break;
        case "/=":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@opset"), [new Ident("div"), ret, rhs]);
            break;
        case "%=":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@opset"), [new Ident("mod"), ret, rhs]);
            break;
        default:
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident(v.value), [ret, rhs]);
            if (cmpOps.canFind(v.value))
            {
                if (opers.length != 1)
                {
                    throw new Exception("invalid parse");
                }
            }
            break;
        }
    }
    return ret;
}

Node readStmt(ref SafeArray!Token tokens)
{
    SafeArray!Token stmtTokens;
    size_t depth;
    while (depth != 0 || !tokens[0].isSemicolon)
    {
        if (tokens[0].isOpen)
        {
            depth++;
        }
        if (tokens[0].isClose)
        {
            depth--;
        }
        stmtTokens ~= tokens[0];
        tokens = tokens[1 .. $];
    }
    tokens = tokens[1 .. $];
    if (stmtTokens.length == 0)
    {
        return null;
    }
    if (stmtTokens[0].isKeyword("return"))
    {
        stmtTokens = stmtTokens[1 .. $];
        return new Call(new Ident("@return"), [stmtTokens.readExpr]);
    }
    if (stmtTokens[0].isKeyword("def"))
    {
        stmtTokens = stmtTokens[1 .. $];
        Node name = new Ident(stmtTokens[0].value);
        stmtTokens = stmtTokens[1 .. $];
        SafeArray!Node args = stmtTokens.readParens;
        Node dobody = stmtTokens.readBlock;
        return new Call(new Ident("@def"), [new Call(name, args), dobody]);
    }
    return stmtTokens.readExpr;
}

Node readBlockBody(ref SafeArray!Token tokens)
{
    SafeArray!Node ret;
    while (tokens.length > 0 && !tokens[0].isClose("}"))
    {
        Node stmt = tokens.readStmt;
        if (stmt !is null)
        {
            ret ~= stmt;
        }
    }
    return new Call(new Ident("@do"), ret);
}

Node readBlock(ref SafeArray!Token tokens)
{
    tokens = tokens[1 .. $];
    Node ret = tokens.readBlockBody;
    tokens = tokens[1 .. $];
    return ret;
}

Node parse(string code)
{
    SafeArray!Token tokens = SafeArray!Token(code.tokenize);
    Node node = tokens.readBlockBody;
    return node;
}
