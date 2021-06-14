module ext.passerine.parse.parse;

import purr.io;
import std.conv;
import std.file;
import std.array;
import std.utf;
import std.functional;
import std.ascii;
import std.string;
import std.algorithm;
import purr.vm;
import purr.inter;
import purr.srcloc;
import purr.inter;
import purr.ir.walk;
import purr.ast.ast;
import ext.passerine.tokens;
import ext.passerine.parse.util;
import ext.passerine.parse.op;

Node readParenBody(ref TokenArray tokens, size_t start)
{
    Node[] args;
    bool hasComma = false;
    while (tokens.length != 0 && !tokens.first.isClose(")"))
    {
        tokens.eat;
        args ~= tokens.readExpr(start);
        tokens.eat;
        if (tokens.length != 0 && tokens.first.isComma)
        {
            tokens.nextIs(Token.Type.comma);
            hasComma = true;
            continue;
        }
        else
        {
            break;
        }
    }
    if (args.length == 0)
    {
        return new Form("tuple");
    }
    if (args.length == 1 && !hasComma)
    {
        return args[0];
    }
    else
    {
        return new Form("tuple", args);
    }
}

/// reads open parens
Node readOpen(string v)(ref TokenArray tokens) if (v == "()")
{
    tokens.nextIs(Token.Type.open, [v[0]]);
    Node ret = tokens.readParenBody(0);
    tokens.nextIs(Token.Type.close, [v[1]]);
    return ret;
}

/// reads square brackets
Node readOpen(string v)(ref TokenArray tokens) if (v == "[]")
{
    tokens.nextIs(Token.Type.open, [v[0]]);
    Node[] args;
    outer: while (!tokens.first.isClose("]"))
    {
        tokens.eat;
        args ~= tokens.readExpr(1);
        tokens.eat;
        if (!tokens.first.isComma)
        {
            break;
        }
        tokens.nextIs(Token.Type.comma);
    }
    tokens.nextIs(Token.Type.close, [v[1]]);
    return new Form("array", args);
}

/// reads open curly brackets
Node[] readOpen(string v)(ref TokenArray tokens) if (v == "{}")
{
    Node[] args;
    tokens.nextIs(Token.Type.open, [v[0]]);
    size_t items = 0;
    while (!tokens.first.isClose([v[1]]))
    {
        args ~= tokens.readExprBase;
        items++;
        if (tokens.first.isComma)
        {
            tokens.nextIs(Token.Type.comma);
        }
    }
    tokens.nextIs(Token.Type.close, [v[1]]);
    return args;
}

// /// strips newlines and changes the input
void stripNewlines(ref TokenArray tokens)
{
    while (tokens.first.isSemicolon)
    {
        tokens.nextIs(Token.Type.semicolon);
    }
}

/// after reading a small expression, read a postfix expression
alias readPostExtend = Spanning!(readPostExtendImpl, Node);
Node readPostExtendImpl(ref TokenArray tokens, Node last)
{
    if (tokens.length != 0 && tokens.first.isOperator("::"))
    {
        Node ret = void;
        tokens.nextIs(Token.Type.operator, "::");
        if (tokens.first.value[0].isDigit)
        {
            ret = new Form("index", [
                    last, new Value(tokens.first.value.to!double)
                    ]);
            tokens.nextIsAny;
        }
        else
        {
            ret = new Form("index", [last, new Value(tokens.first.value)]);
            tokens.nextIsAny;
        }
        return tokens.readPostExtend(ret);
    }
    else
    {
        return last;
    }
}

void skip1(ref string str, ref Span span)
{
    if (str[0] == '\n')
    {
        span.first.line += 1;
        span.first.column = 1;
    }
    else
    {
        span.first.column += 1;
    }
    str = str[1 .. $];
}

bool isDigitInBase(char c, long base)
{
    if (base > 0 && base < 10)
    {
        return c - '0' < base;
    }
    if (base == 10)
    {
        return c.isDigit;
    }
    if (base > 10)
    {
        long val = c;
        if (val >= 'A' && val <= 'A')
        {
            val = val - 'A' + 'a';
        }
        bool isLetterDigit = val >= 10 && val < base;
        return isLetterDigit || c.isDigitInBase(10);
    }
    throw new Exception("base not valud: " ~ base.to!string);
}

long parseNumberOnly(ref string input, size_t base)
{
    string str;
    while (input.length != 0 && input[0].isDigitInBase(base))
    {
        str ~= input[0];
        input = input[1 .. $];
    }
    if (str.length == 0)
    {
        throw new Exception("found no digits when parse escape in base " ~ base.to!string);
    }
    return str.to!size_t(cast(uint) base);
}

size_t escapeNumber(ref string input)
{
    if (input[0] == '0')
    {
        char ctrlchr = input[1];
        input = input[2 .. $];
        switch (ctrlchr)
        {
        case 'b':
            return input.parseNumberOnly(2);
        case 'o':
            return input.parseNumberOnly(8);
        case 'x':
            return input.parseNumberOnly(16);
        default:
            string why = "0 must be followed by one of: nbox";
            throw new Exception("cannot have escape: " ~ why);
        }
    }
    else
    {
        return input.parseNumberOnly(10);
    }
}

/// reads first element of postfix expression
alias readPostExpr = Spanning!readPostExprImpl;
Node readPostExprImpl(ref TokenArray tokens)
{
    tokens.eat;
    Node last = void;
redo:
    if (tokens.first.isKeyword("magic"))
    {
        tokens.nextIs(Token.Type.keyword, "magic");
        string word = tokens.first.value;
        tokens.nextIs(Token.Type.string, word);
        switch (word)
        {
        case "if":
            if (tokens.first.isOpen("("))
            {
                tokens.nextIs(Token.type.open, "(");
                Node cond = tokens.readExpr(1);
                tokens.nextIs(Token.Type.comma);
                Node iftrue = tokens.readExpr(1);
                tokens.nextIs(Token.Type.comma);
                Node iffalse = tokens.readExpr(1);
                if (tokens.first.isComma)
                {
                    tokens.nextIs(Token.Type.comma);
                }
                tokens.eat;
                tokens.nextIs(Token.type.close, ")");
                last = new Form("if", cond, iftrue, iffalse);
            }
            else
            {
                throw new Exception("Magic If");
            }
            break;
        case "add":
            if (tokens.first.isOpen("("))
            {
                tokens.nextIs(Token.type.open, "(");
                Node lhs = tokens.readExpr(1);
                tokens.nextIs(Token.Type.comma);
                Node rhs = tokens.readExpr(1);
                if (tokens.first.isComma)
                {
                    tokens.nextIs(Token.Type.comma);
                }
                tokens.nextIs(Token.type.close, ")");
                last = new Form("+", lhs, rhs);
            }
            else
            {
                throw new Exception("Magic Add");
            }
            break;
        case "sub":
            if (tokens.first.isOpen("("))
            {
                tokens.nextIs(Token.type.open, "(");
                Node lhs = tokens.readExpr(1);
                tokens.nextIs(Token.Type.comma);
                Node rhs = tokens.readExpr(1);
                if (tokens.first.isComma)
                {
                    tokens.nextIs(Token.Type.comma);
                }
                tokens.nextIs(Token.type.close, ")");
                last = new Form("-", lhs, rhs);
            }
            else
            {
                throw new Exception("Magic Sub");
            }
            break;
        // case "to_string":
        //     last = new Value(native!magictostring);
        //     break;
        case "print":
            last = new Ident("print");
            break;
        case "println":
            last = new Ident("println");
            break;
        case "equal":
            if (tokens.first.isOpen("("))
            {
                tokens.nextIs(Token.type.open, "(");
                Node lhs = tokens.readExpr(1);
                tokens.nextIs(Token.Type.comma);
                Node rhs = tokens.readExpr(1);
                tokens.nextIs(Token.type.close, ")");
                last = new Form("==", lhs, rhs);
            }
            else
            {
                throw new Exception("Magic Equals");
            }
            break;
        case "greater":
            if (tokens.first.isOpen("("))
            {
                tokens.nextIs(Token.type.open, "(");
                Node lhs = tokens.readExpr(1);
                tokens.nextIs(Token.Type.comma);
                Node rhs = tokens.readExpr(1);
                tokens.nextIs(Token.type.close, ")");
                last = new Form(">", lhs, rhs);
            }
            else
            {
                throw new Exception("Magic Greater");
            }
            break;
        default:
            throw new Exception("not implemented: magic " ~ word);
        }
    }
    else if (tokens.first.isOpen("("))
    {
        last = tokens.readOpen!"()";
    }
    else if (tokens.first.isOpen("["))
    {
        last = tokens.readOpen!"[]";
    }
    else if (tokens.first.isOpen("{"))
    {
        last = tokens.readBlock;
    }
    else if (tokens.first.isIdent)
    {
        switch (tokens.first.value)
        {
        default:
            if (tokens.first.value.isNumeric)
            {
                last = new Value(tokens.first.value.to!double);
                tokens.nextIs(Token.Type.ident);
            }
            else
            {
                if (tokens.first.value[0].isDigit)
                {
                    last = new Value(tokens.first.value.to!double);
                }
                else
                {
                    last = new Ident(tokens.first.value);
                }
                tokens.nextIs(Token.Type.ident);
            }
            break;
        case "true":
            last = new Value(true);
            tokens.nextIs(Token.Type.ident);
            break;
        case "false":
            last = new Value(false);
            tokens.nextIs(Token.Type.ident);
            break;
        }
    }
    else if (tokens.first.isString)
    {
        last = new Value(tokens.first.value);
        tokens.nextIs(Token.Type.string);
    }
    else
    {
        last = new Value(null);
    }
    return tokens.readPostExtend(last);
}

/// read prefix before postfix expression.
alias readPreExpr = Spanning!readPreExprImpl;
Node readPreExprImpl(ref TokenArray tokens)
{
    if (tokens.first.isOperator)
    {
        string[] vals;
        while (tokens.first.isOperator)
        {
            vals ~= tokens.first.value;
            tokens.nextIs(Token.Type.operator);
            tokens.eat;
        }
        return parseUnaryOp(vals)(tokens.readPostExpr);
    }
    TokenArray lastTokens = tokens;
    Node callChain = tokens.readPostExpr;
    TokenArray[] tokens2 = [lastTokens[0..lastTokens.length - tokens.length]];
    lastTokens = tokens;

    while (tokens.length != 0 && !tokens.first.isSemicolon
            && !tokens.first.isClose && !tokens.first.isComma && !tokens.first.isOperator)
    {
        size_t llen = tokens.length;
        Node arg = tokens.readPostExpr;
        tokens2 ~= lastTokens[0..lastTokens.length - tokens.length];
        callChain = new Form("call", callChain, arg);
        if (llen == tokens.length)
        {
            break;
        }
        lastTokens = tokens;
    }
    return callChain;
}

alias readExprBase = Spanning!(readExprBaseImpl);
/// reads any expresssion with precedence of zero
Node readExprBaseImpl(ref TokenArray tokens)
{
    return tokens.readExpr(0);
}

bool isAnyOperator(Token tok, string[] ops)
{
    foreach (op; ops)
    {
        if (tok.isOperator(op))
        {
            return true;
        }
    }
    return false;
}

alias readExpr = Spanning!(readExprImpl, size_t);
/// reads any expresssion
Node readExprImpl(ref TokenArray tokens, size_t level)
{
    if (level == prec.length)
    {
        return tokens.readPreExpr;
    }
    string[] opers;
    Node[] subNodes;
    if (prec[level].canFind("="))
    {
        subNodes ~= tokens.readParenBody(level + 1);
    }
    else
    {
        subNodes ~= tokens.readExpr(level + 1);
    }
    while (tokens.length != 0 && tokens.first.isAnyOperator(prec[level]))
    {
        opers ~= tokens.first.value;
        tokens.nextIsAny;
        tokens.eat;
        if (prec[level].canFind("="))
        {
            subNodes ~= tokens.readParenBody(level + 1);
        }
        else
        {
            subNodes ~= tokens.readExpr(level + 1);
        }
    }
    if (opers.length == 0)
    {
        return subNodes[0];
    }
    else if (opers[0] == "->")
    {
        Node ret = subNodes[$ - 1];
        foreach (i, v; opers)
        {
            ret = parseBinaryOp(["->"])(subNodes[$ - 2 - i], ret);
        }
        return ret;
    }
    else
    {
        Node ret = subNodes[0];
        foreach (i, v; opers)
        {
            ret = parseBinaryOp([v])(ret, subNodes[i + 1]);
        }
        return ret;
    }
}

/// reads any statement ending in a semicolon
alias readStmt = Spanning!readStmtImpl;
Node readStmtImpl(ref TokenArray tokens)
{
    tokens.eat;
    if (tokens.length == 0)
    {
        return null;
    }
    Node ret = tokens.readExprBase;
    tokens.eat;
    return ret;
}

/// reads many staments statement, each ending in a semicolon
/// does not read brackets surrounding
alias readBlockBody = Spanning!readBlockBodyImpl;
Node readBlockBodyImpl(ref TokenArray tokens)
{
    Node[] ret;
    while (tokens.length > 0 && !tokens.first.isClose("}"))
    {
        size_t lengthBefore = tokens.length;
        Node stmt = tokens.readStmt;
        if (stmt !is null)
        {
            ret ~= stmt;
        }
        if (tokens.length == lengthBefore)
        {
            break;
        }
    }
    return new Form("do", ret);
}

/// wraps the readblock and consumes curly braces
alias readBlock = Spanning!readBlockImpl;
Node readBlockImpl(ref TokenArray tokens)
{
    tokens.nextIs(Token.Type.open, "{");
    Node ret = readBlockBody(tokens);
    tokens.nextIs(Token.Type.close, "}");
    return ret;
}

alias parsePasserineValue = parsePasserineAs!readBlockBodyImpl;
alias parsePasserine = memoize!parsePasserineValue;
/// parses code as the passerine programming language
Node parsePasserineAs(alias parser)(SrcLoc loc)
{
    TokenArray tokens = newTokenArray(loc.tokenize);
    try
    {
        Node node = parser(tokens);
        return node;
    }
    catch (Exception e)
    {
        string[] lines = loc.src.split("\n");
        size_t[] nums;
        size_t ml = 0;
        foreach (i; locs)
        {
            if (nums.length == 0 || nums[$ - 1] < i.line)
            {
                nums ~= i.line;
                ml = max(ml, i.line.to!string.length);
            }
        }
        string ret;
        foreach (i; nums)
        {
            string s = i.to!string;
            foreach (j; 0 .. ml - s.length)
            {
                ret ~= ' ';
            }
            if (i > 0 && i < lines.length)
            {
                ret ~= i.to!string ~ ": " ~ lines[i - 1].to!string ~ "\n";
            }
        }
        e.msg = ret ~ e.msg;
        throw e;
    }
}

/// parses code as archive of the passerine programming language
Node parse(SrcLoc loc)
{
    SrcLoc location = loc;
    Node ret = location.parsePasserine;
    return ret;
}
