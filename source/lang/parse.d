module lang.parse;

import lang.ast;
import lang.tokens;
import std.stdio;
import std.conv;
import std.algorithm;

enum string[] cmpOps = ["<", ">", "<=", ">=", "==", "!="];

version = push_array;

struct PushArray(T)
{
    T[] tokens;

    T opIndex(size_t i)
    {
        if (i >= tokens.length) {
            throw new Exception("parse error");
        }
        return tokens[i];
    }

    void opOpAssign(string S)(T v) if (S == "~")
    {
        tokens ~= v;
    }

    PushArray!T opSlice(size_t i, size_t j)
    {
        // if (j >= i || tokens.length > j) {
        //     throw new Exception("parse error");
        // }
        return PushArray(tokens[i .. j]);
    }

    int opApply(scope int delegate(ref T) dg)
    {
        int result = 0;

        foreach (item; tokens)
        {
            result = dg(item);
            if (result)
                break;
        }

        return result;
    }

    int opApply(scope int delegate(size_t, ref T) dg)
    {
        int result = 0;

        foreach (k, item; tokens)
        {
            result = dg(k, item);
            if (result)
                break;
        }

        return result;
    }

    size_t length()
    {
        return tokens.length;
    }

    size_t opDollar()
    {
        return tokens.length;
    }

    string toString()
    {
        return tokens.to!string;
    }
}

version (push_array)
{
    alias TokenArray = PushArray!Token;

    TokenArray newTokenArray(Token[] a)
    {
        return TokenArray(a);
    }
}
else
{
    alias TokenArray = Token[];

    TokenArray newTokenArray(T...)(Token[] a)
    {
        return a;
    }
}

Node[] readOpen(string v)(ref TokenArray tokens) if (v != "{}")
{
    Node[] args;
    tokens = tokens[1 .. $];
    tokens.stripNewlines;
    while (!tokens[0].isClose([v[1]]))
    {
        args ~= tokens.readExpr;
        tokens.stripNewlines;
        if (tokens[0].isComma)
        {
            tokens = tokens[1 .. $];
        }
    }
    tokens = tokens[1 .. $];
    return args;
}

Node[] readOpen(string v)(ref TokenArray tokens) if (v == "{}")
{
    Node[] args;
    tokens = tokens[1 .. $];
    size_t items = 0;
    tokens.stripNewlines;
    while (!tokens[0].isClose([v[1]]))
    {
        args ~= tokens.readExpr;
        tokens.stripNewlines;
        items++;
        // if ((items % 2 == 0 && tokens[0].isComma) || (items % 2 == 1 && tokens[0].isOperator(":")))
        if (tokens[0].isComma || tokens[0].isOperator(":"))
        {
            tokens = tokens[1 .. $];
        }
    }
    tokens = tokens[1 .. $];
    return args;
}

void stripNewlines(ref TokenArray tokens)
{
    while (tokens[0].isSemicolon)
    {
        tokens = tokens[1 .. $];
    }
}

alias readParens = readOpen!"()";
alias readSquare = readOpen!"[]";
alias readBrace = readOpen!"{}";

Node readPostExtend(ref TokenArray tokens, Node last)
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
    return tokens.readPostExtend(ret);
}

Node readIf(ref TokenArray tokens)
{
    Node[] cond = tokens.readParens;
    assert(cond.length == 1);
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

Node readUsing(ref TokenArray tokens)
{
    Node[] obj = tokens.readParens;
    assert(obj.length == 1);
    Node bod = tokens.readBlock;
    return new Call(new Ident("@using"), [obj[0], bod]);
}

Node readTableCons(ref TokenArray tokens)
{
    Node bod = tokens.readBlock;
    return new Call(new Ident("@using"), [new Call(new Ident("@table"), []), bod]);
}

Node readPostExpr(ref TokenArray tokens)
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

Node readPreExpr(ref TokenArray tokens)
{
    if (tokens[0].isOperator)
    {
        Token op = tokens[0];
        tokens = tokens[1 .. $];
        size_t count;
        while (tokens[0].isOperator("."))
        {
            count++;
            tokens = tokens[1 .. $];
        }
        string val = op.value;
        if (val == "*")
        {
            val = "...";
        }
        Node ret = new Call(new Ident(val), [tokens.readPreExpr]);
        foreach (i; 0 .. count)
        {
            Call call = cast(Call) ret;
            ret = new Call(new Ident("@dotmap-pre"), call.args);
        }
        return ret;
    }
    return tokens.readPostExpr;
}

size_t[2] countDots(ref TokenArray tokens)
{
    size_t pre;
    size_t post;
    while (tokens.length != 0 && tokens[0].isOperator("."))
    {
        pre += 1;
        tokens = tokens[1 .. $];
    }
    while (tokens.length != 0 && tokens[$ - 1].isOperator("."))
    {
        post += 1;
        tokens = tokens[0 .. $ - 1];
    }
    return [pre, post];
}

Node readExpr(ref TokenArray tokens, size_t level = 0)
{
    if (level == prec.length)
    {
        return tokens.readPreExpr;
    }
    TokenArray[] sub = [TokenArray.init];
    TokenArray opers = TokenArray.init;
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
                    sub ~= TokenArray.init;
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
        lastIsOp = token.isOperator && !token.isOperator(".");
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
    size_t[2][] dotcount = [[0, 0]];
    typeof(sub) sub2 = sub.dup;
    foreach (i, ref v; sub)
    {
        size_t[2] dc = v.countDots;
        dotcount[$ - 1][1] += dc[0];
        dotcount ~= [dc[1], 0];
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
            size_t lhsc = dotcount[i + 1][0];
            size_t rhsc = dotcount[i + 1][1];
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident(v.value), [ret, rhs]);
            if (cmpOps.canFind(v.value))
            {
                assert(opers.length == 1);
            }
            while (rhsc != 0 || lhsc != 0)
            {
                Call call = cast(Call) ret;
                if (lhsc > rhsc)
                {
                    lhsc--;
                    ret = new Call(new Ident("@dotmap-lhs"), call.args);
                }
                else if (rhsc > lhsc)
                {
                    rhsc--;
                    ret = new Call(new Ident("@dotmap-rhs"), call.args);
                }
                else if (lhsc == rhsc && lhsc != 0)
                {
                    lhsc--;
                    rhsc--;
                    ret = new Call(new Ident("@dotmap-both"), call.args);
                }
            }
            break;
        }
    }
    return ret;
}

Node readStmt(ref TokenArray tokens)
{
    Token[] stmtTokens0;
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
        stmtTokens0 ~= tokens[0];
        tokens = tokens[1 .. $];
    }
    tokens = tokens[1 .. $];
    TokenArray stmtTokens = newTokenArray(stmtTokens0);
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
        Node[] args = stmtTokens.readParens;
        Node dobody = stmtTokens.readBlock;
        return new Call(new Ident("@def"), [new Call(name, args), dobody]);
    }
    return stmtTokens.readExpr;
}

Node readBlockBody(ref TokenArray tokens)
{
    Node[] ret;
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

Node readBlock(ref TokenArray tokens)
{
    tokens = tokens[1 .. $];
    Node ret = readBlockBody(tokens);
    tokens = tokens[1 .. $];
    return ret;
}

Node parse(string code)
{
    TokenArray tokens = newTokenArray(code.tokenize);
    Node node = tokens.readBlockBody;
    return node;
}
