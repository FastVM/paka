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
import purr.ast.cons;
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
import passerine.parse.pattern;
import passerine.parse.op;
import passerine.parse.syntax;

Node readParenBody(ref TokenArray tokens, size_t start)
{
    Node[] args;
    bool hasComma = false;
    while (tokens.length != 0 && !tokens.first.isClose(")"))
    {
        tokens.eat;
        args ~= tokens.readExpr(start);
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
    while (!tokens.first.isClose("]"))
    {
        tokens.eat;
        args ~= tokens.readExpr(1);
        if (tokens.first.isComma)
        {
            tokens.nextIs(Token.Type.comma);
            continue;
        }
        else
        {
            break;
        }
    }
    tokens.nextIs(Token.Type.close, [v[1]]);
    return new Call(new Ident("@array"), args);
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
            ret = new Call(new Ident("@index"), [
                    last, new Value(tokens.first.value.to!double)
                    ]);
            tokens.nextIsAny;
        }
        else
        {
            ret = new Call(new Ident("@index"), [
                    last, new Value(tokens.first.value)
                    ]);
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

Node readMatch(ref TokenArray tokens)
{
    tokens.nextIs(Token.Type.keyword, "match");
    Node value = tokens.readPostExpr;
    Node[2][] ret;
    tokens.nextIs(Token.Type.open, "{");
    while (tokens.length > 0 && !tokens.first.isClose("}"))
    {
        size_t lengthBefore = tokens.length;
        Node cond = tokens.readExpr(2);
        tokens.nextIs(Token.Type.operator, "->");
        Node stmt = tokens.readStmt;
        if (stmt !is null)
        {
            ret ~= [cond, stmt];
        }
        if (tokens.length == lengthBefore)
        {
            break;
        }
    }
    tokens.nextIs(Token.Type.close, "}");
    Node match = new Value(Dynamic.nil);
    Node sym = genSym;
    foreach_reverse (pair; ret)
    {
        Node cond = matcher(sym, pair[0]);
        match = new Call(new Ident("@if"), [cond, pair[1], match]);
    }
    Node assign = new Call(new Ident("@set"), [sym, value]);
    return new Call(new Ident("@do"), [assign, match]);
}

/// reads first element of postfix expression
alias readPostExpr = Spanning!readPostExprImpl;
Node readPostExprImpl(ref TokenArray tokens)
{
    tokens.eat;
    Node last = void;
redo:
    if (tokens.first.isKeyword("syntax"))
    {
        tokens.readSyntax;
        return new Value(Dynamic.nil);
    }
    else if (tokens.first.isKeyword("match"))
    {
        last = tokens.readMatch();
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
                last = new Call(new Ident("@if"), [cond, iftrue, iffalse]);
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
                last = new Call(new Ident("+"), [lhs, rhs]);
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
                last = new Call(new Ident("-"), [lhs, rhs]);
            }
            else
            {
                throw new Exception("Magic Sub");
            }
            break;
        case "to_string":
            last = new Value(native!magictostring);
            break;
        case "print":
            last = new Value(native!magicprint);
            break;
        case "println":
            last = new Value(native!magicprintln);
            break;
        case "equal":
            if (tokens.first.isOpen("("))
            {
                tokens.nextIs(Token.type.open, "(");
                Node lhs = tokens.readExpr(1);
                tokens.nextIs(Token.Type.comma);
                Node rhs = tokens.readExpr(1);
                tokens.nextIs(Token.type.close, ")");
                last = new Call(new Ident("=="), [lhs, rhs]);
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
                last = new Call(new Ident(">"), [lhs, rhs]);
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
            if (tokens.first.value[0].isUpper)
            {
                Node name = new Value(Dynamic.sym(tokens.first.value));
                tokens.nextIsAny;
                last = new Call(new Ident("@array"), [name, tokens.readPostExpr]);
            }
            else if (tokens.first.value.isNumeric)
            {
                last = new Value(tokens.first.value.to!double);
                tokens.nextIs(Token.Type.ident);
            }
            else
            {
                if (nameSubs.length == 0)
                {
                    last = new Ident(tokens.first.value);
                }
                else if (Dynamic* ret = tokens.first.value.dynamic in nameSubs[$ - 1])
                {
                    last = getNode(*ret);
                }
                else
                {
                    last = new Ident(tokens.first.value);
                    // Node sym = genSym;
                    // nameSubs[$ - 1].set(tokens.first.value.dynamic, sym.astDynamic);
                    // last = sym;
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
        last = new Value(Dynamic.nil);
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
    Node ret = tokens.readPostExpr;
    while (tokens.length != 0 && !tokens.first.isSemicolon
            && !tokens.first.isClose && !tokens.first.isComma && !tokens.first.isOperator)
    {
        size_t llen = tokens.length;
        ret = new Call(new Ident("@call"), [ret, tokens.readPostExpr]);
        if (llen == tokens.length)
        {
            break;
        }
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
        Node ret = tokens.readPreExpr;
    redo:
        outter: foreach_reverse (macros; syntaxMacros)
        {
            foreach (Dynamic[2] pair; macros)
            {
                Dynamic pattern = pair[0];
                Dynamic astBody = pair[1];
                if (Table reps = pattern.arr.matchMacro(ret))
                {
                    nameSubs ~= reps;
                    TokenArray toks = astBody.getTokens;
                    ret = toks.readBlock;
                    nameSubs.length--;
                    goto redo;
                }
            }
        }
        return ret;
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
    return new Call(new Ident("@do"), ret);
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
    scope (exit)
    {
        locs = olocs;
        staticCtx.length--;
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
