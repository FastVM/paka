module passerine.parse.parse;

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
import purr.base;
import purr.dynamic;
import purr.srcloc;
import purr.inter;
import purr.fs.disk;
import purr.fs.har;
import purr.fs.memory;
import purr.fs.files;
import purr.bytecode;
import purr.ir.walk;
import purr.ast.ast;
import passerine.magic;
import passerine.tokens;
import passerine.parse.util;
import passerine.parse.op;

/// reads open parens
Node readOpen(string v)(ref TokenArray tokens) if (v == "()")
{
    Node[] args;
    bool hasComma = false;
    tokens.nextIs(Token.Type.open, [v[0]]);
    while (!tokens.first.isClose([v[1]]))
    {
        args ~= tokens.readExprBase;
        if (tokens.first.isComma)
        {
            tokens.nextIs(Token.Type.comma);
            hasComma = true;
        }
        else if (tokens.first.isClose([v[1]]))
        {
            break;
        }
        else
        {
            throw new Exception("comma");
        }
    }
    tokens.nextIs(Token.Type.close, [v[1]]);
    if (args.length == 0)
    {
        return new Call(new Ident("@array"), null);
    }
    if (args.length == 1 && !hasComma)
    {
        return args[0];
    }
    else
    {
        return new Call(new Ident("@array"), args);
    }
}

/// reads square brackets
Node[] readOpen(string v)(ref TokenArray tokens) if (v == "[]")
{
    Node[] args;
    tokens.nextIs(Token.Type.open, [v[0]]);
    while (!tokens.first.isClose([v[1]]))
    {
        args ~= tokens.readExprBase;
        if (tokens.first.isComma)
        {
            tokens.nextIs(Token.Type.comma);
        }
    }
    tokens.nextIs(Token.Type.close, [v[1]]);
    return args;
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
    if (tokens.length == 0)
    {
        return last;
    }
    Node ret = void;
    if (tokens.length > 2 && tokens.first.isOperator("."))
    {
        tokens.nextIs(Token.Type.operator, ".");
        if (tokens.first.value[0].isDigit)
        {
            throw new Exception("index");
        }
        else
        {
            ret = new Call(new Ident("@index"), [last, new Value(tokens.first.value)]);
            tokens.nextIsAny;
        }
    }
    else if (tokens.first.isOperator(".") && !tokens.first.isOperator)
    {
        tokens.nextIs(Token.Type.operator, ".");
    }
    else
    {
        return last;
        // throw new Exception("parse error " ~ tokens.to!string);
    }
    return tokens.readPostExtend(ret);
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
    Node last = void;
    if (tokens.first.isKeyword("syntax"))
    {
        throw new Exception("Syntax");
    }
    else if (tokens.first.isKeyword("magic"))
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
                Node cond = tokens.readExprBase;
                tokens.nextIs(Token.Type.comma);
                Node iftrue = tokens.readExprBase;
                tokens.nextIs(Token.Type.comma);
                Node iffalse = tokens.readExprBase;
                tokens.nextIs(Token.type.close, ")");
                return new Call(new Ident("@if"), [cond, iftrue, iffalse]);
            }
            else
            {
                throw new Exception("Magic If");
            }   
        case "greater":
            if (tokens.first.isOpen("("))
            {
                tokens.nextIs(Token.type.open, "(");
                Node lhs = tokens.readExprBase;
                tokens.nextIs(Token.Type.comma);
                Node rhs = tokens.readExprBase;
                tokens.nextIs(Token.type.close, ")");
                return new Call(new Ident(">"), [lhs, rhs]);
            }
            else
            {
                throw new Exception("Magic Greater");
            }
        default:
            throw new Exception("magic " ~ word);
        }
    }
    else if (tokens.first.isOpen("("))
    {
        return tokens.readOpen!"()";
    }
    else if (tokens.first.isOpen("["))
    {
        throw new Exception("Square");
    }
    else if (tokens.first.isOpen("{"))
    {
        throw new Exception("Curly");
    }
    else if (tokens.first.isIdent)
    {
        last = new Ident(tokens.first.value);
        tokens.nextIs(Token.Type.ident);
    }
    else if (tokens.first.isString)
    {
        last = new Value(tokens.first.value);
        tokens.nextIs(Token.Type.string);
    }
    else
    {
        throw new Exception("end");
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
        }
        return parseUnaryOp(vals)(tokens.readPostExpr);
    }
    Node ret = tokens.readPostExpr;
    while (!tokens.first.isSemicolon && !tokens.first.isClose && !tokens.first.isComma && !tokens.first.isOperator)
    {
        ret = new Call(new Ident("@call"), [ret, tokens.readPreExprImpl]);
    }
    return ret;
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
    Node[] subNodes = [tokens.readExpr(level + 1)];
    while (tokens.length != 0 && tokens.first.isAnyOperator(prec[level]))
    {
        opers ~= tokens.first.value;
        tokens.nextIsAny;
        subNodes ~= tokens.readExpr(level + 1);
    }
    Node ret = subNodes[0];
    Ident last;
    foreach (i, v; opers)
    {
        ret = parseBinaryOp([v])(ret, subNodes[i+1]);
    }
    return ret;
}

/// reads any statement ending in a semicolon
alias readStmt = Spanning!readStmtImpl;
Node readStmtImpl(ref TokenArray tokens)
{
    if (tokens.length == 0)
    {
        return null;
    }
    while (tokens.length > 0 && tokens.first.isSemicolon)
    {
        tokens.nextIs(Token.Type.semicolon);
        if (tokens.length == 0)
        {
            return null;
        }
    }
    scope (exit)
    {
        while (tokens.length > 0 && tokens.first.isSemicolon)
        {
            tokens.nextIs(Token.Type.semicolon);
        }
    }
    if (tokens.length == 0)
    {
        return null;
    }
    return tokens.readExprBase;
}

/// reads many staments statement, each ending in a semicolon
/// does not read brackets surrounding
alias readBlockBody = Spanning!readBlockBodyImpl;
Node readBlockBodyImpl(ref TokenArray tokens)
{
    Node[] ret;
    while (tokens.length > 0 && !tokens.first.isClose("}") && !tokens.first.isKeyword("else"))
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
    return new Call(new Ident("@do"), ret);
}

/// wraps the readblock and consumes curly braces
alias readBlock = Spanning!readBlockImpl;
Node readBlockImpl(ref TokenArray tokens)
{
    if (tokens.first.isOperator(":"))
    {
        tokens.nextIs(Token.Type.operator, ":");
        return tokens.readStmt;  
    }
    else
    {
        tokens.nextIs(Token.Type.open, "{");
        Node ret = readBlockBody(tokens);
        tokens.nextIs(Token.Type.close, "}");
        return ret;
    }
}

alias parsePasserineValue = parsePasserineAs!readBlockBodyImpl;
alias parsePasserine = memoize!parsePasserineValue;
/// parses code as the passerine programming language
Node parsePasserineAs(alias parser)(Location loc)
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
Node parse(Location loc)
{
    Location[] olocs = locs;
    locs = null;
    staticCtx ~= enterCtx;
    prefixMacros ~= emptyMapping;
    scope (exit)
    {
        locs = olocs;
        staticCtx.length--;
        prefixMacros.length--;
    }
    fileSystem ~= parseHar(loc, fileSystem);
    MemoryTextFile main = "main.passerine".readMemFile;
    if (main is null)
    {
        main = "__main__".readMemFile;
    }
    if (main is null)
    {
        throw new Exception("input error: missing __main__");
    }
    Location location = main.location;
    Node ret = location.parsePasserine;
    return ret;
}
