module lang.dext.parse;

import lang.ast;
import lang.dext.tokens;
import std.stdio;
import std.conv;
import std.array;
import std.traits;
import std.algorithm;
import lang.srcloc;

/// safe array of tokens
alias TokenArray = PushArray!Token;

/// operators for comparrason
enum string[] cmpOps = ["<", ">", "<=", ">=", "==", "!="];

/// locations for error handling
Location[] locs;

/// wraps a function of type Node function(T...)(TokenArray tokens, T args).
/// it gets the span of tokens consumed and it gives them a span
template Spanning(alias F)
{
    alias T = Parameters!F[1 .. $];
    Node Spanning(ref TokenArray tokens, T a)
    {
        TokenArray orig = tokens;
        if (orig.length != 0)
        {
            locs ~= orig[0].span.first;
        }
        scope (success)
        {
            if (orig.length != 0)
            {
                locs.length--;
            }
        }
        Node ret = F(tokens, a);
        if (orig.length != 0 && ret !is null)
        {
            ret.span = Span(orig[0].span.first, orig[orig.length - tokens.length - 1].span.last);
        }
        return ret;
    }
}

/// array that is bounds checked always and throws decent errors.
/// usually used as a TokenArray.
struct PushArray(T)
{
    /// the tokens is just an array
    T[] tokens;

    /// safely index the array
    T opIndex(size_t i)
    {
        if (i >= tokens.length)
        {
            throw new Exception("parse error 1");
        }
        return tokens[i];
    }

    // utils that only happens if the token is a token array
    static if (is(T == Token))
    {
        /// consumes token if it is of type, returns weather it was consumed
        bool match(Token.Type type)
        {
            if (this[0].type == type)
            {
                tokens = tokens[1 .. $];
                return true;
            }
            return false;
        }

        /// consumes token matching the args, returns weather it was consumed
        bool match(Token.Type type, string val)
        {
            if (this[0].type == type && this[0].value == val)
            {
                tokens = tokens[1 .. $];
                return true;
            }
            return false;
        }

        /// wraps match, it throws a nice error when it does not match
        void nextIs(T...)(T a)
        {
            if (!match(a))
            {
                throw new Exception("expected " ~ a[$ - 1].to!string ~ " got " ~ this[0].to!string);
            }
        }

        /// this just skips a token, often used for bracket matching
        void nextIsAny()
        {
            tokens = tokens[1 .. $];
        }
    }
    PushArray!T opSlice(size_t i, size_t j)
    {
        if (j < i || tokens.length < j)
        {
            throw new Exception("parse error 2");
        }
        return PushArray(tokens[i .. j]);
    }

    /// appends to the array
    void opOpAssign(string S)(T v) if (S == "~")
    {
        tokens ~= v;
    }

    /// implements foreach(i; this)
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

    /// implements foreach(i, ref v; this)
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

    /// the length of the array, not often needed, errors are prefered
    size_t length()
    {
        return tokens.length;
    }

    /// this is the same as length
    size_t opDollar()
    {
        return tokens.length;
    }

    /// the same as this.tokens.to!string
    string toString()
    {
        return tokens.to!string;
    }
}

/// implements errors when the parser knows what should be next
void skip(ref TokenArray tokens, string name)
{
    if (tokens.length == 0 || tokens[0].value != name)
    {
        throw new Exception("parse error: got " ~ tokens[0].value ~ " found " ~ name);
    }
}

// TODO: replace with TokenArray calls
/// constructs a token array, this will soon be replaced
TokenArray newTokenArray(Token[] a)
{
    return TokenArray(a);
}

/// reads open parens or square brackets
/// ignores commas, soon to handle them correctly
Node[] readOpen(string v)(ref TokenArray tokens) if (v != "{}")
{
    Node[] args;
    tokens.match(Token.Type.open, [v[0]]);
    tokens.stripNewlines;
    while (!tokens[0].isClose([v[1]]))
    {
        args ~= tokens.readExpr(0);
        tokens.stripNewlines;
        if (tokens[0].isComma)
        {
            tokens.nextIs(Token.Type.comma);
        }
    }
    tokens.match(Token.Type.close, [v[1]]);
    return args;
}

// TODO: make commas and colons alternate
/// reads open curly brackets
Node[] readOpen(string v)(ref TokenArray tokens) if (v == "{}")
{
    Node[] args;
    tokens.match(Token.Type.open, [v[0]]);
    size_t items = 0;
    tokens.stripNewlines;
    while (!tokens[0].isClose([v[1]]))
    {
        args ~= tokens.readExpr(0);
        tokens.stripNewlines;
        items++;
        // if ((items % 2 == 0 && tokens[0].isComma) || (items % 2 == 1 && tokens[0].isOperator(":")))
        if (tokens[0].isComma)
        {
            tokens.nextIs(Token.Type.comma);
        }
        else if (tokens[0].isOperator(":"))
        {
            tokens.nextIs(Token.Type.operator, ":");
        }
    }
    tokens.match(Token.Type.close, [v[1]]);
    return args;
}

/// strips newlines and changes the input
void stripNewlines(ref TokenArray tokens)
{
    while (tokens[0].isSemicolon)
    {
        tokens.nextIs(Token.Type.semicolon);
    }
}

/// read open paren until close paren.
/// used for arguments and flow control
alias readParens = readOpen!"()";
/// read open square bracket until close square bracket.
/// used for arrays and indexing 
alias readSquare = readOpen!"[]";
/// read open curly bracket until close curly bracket.
/// used for tables 
alias readBrace = readOpen!"{}";

/// after reading a small expression, read a postfix expression
alias readPostExtend = Spanning!readPostExtendImpl;
Node readPostExtendImpl(ref TokenArray tokens, Node last)
{
    if (tokens.length == 0)
    {
        return last;
    }
    Node ret = void;
    if (tokens[0].isOpen("("))
    {
        Node[] args = tokens.readParens;
        while (tokens.length != 0 && tokens[0].isOpen("{"))
        {
            args ~= cast(Node) new Call(new Ident("@fun"), [
                    new Call([]), tokens.readBlock
                    ]);
        }
        ret = new Call(last, args);
    }
    else if (tokens[0].isOpen("{"))
    {
        Node[] args;
        while (tokens[0].isOpen("{"))
        {
            args ~= cast(Node) new Call(new Ident("@fun"), [
                    new Call([]), tokens.readBlock
                    ]);
        }
        ret = new Call(last, args);
    }
    else if (tokens[0].isOpen("["))
    {
        ret = new Call(new Ident("@index"), last ~ tokens.readSquare);
    }
    else if (tokens[0].isOperator("."))
    {
        tokens.nextIs(Token.Type.operator, ".");
        ret = new Call(new Ident("@index"), [last, new String(tokens[0].value)]);
        tokens.nextIs(Token.Type.ident);
    }
    else
    {
        throw new Exception("parse error");
    }
    return tokens.readPostExtend(ret);
}

/// read an if statement
alias readIf = Spanning!readIfImpl;
Node readIfImpl(ref TokenArray tokens)
{
    Node[] cond = tokens.readParens;
    if (tokens.length < 1)
    {
        throw new Exception("if cannot have empty parens");
    }
    Node iftrue = tokens.readBlock;
    Node iffalse;
    if (tokens.length != 0 && tokens[0].isKeyword("else"))
    {
        tokens.nextIs(Token.Type.keyword, "else");
        iffalse = tokens.readBlock;
    }
    else
    {
        iffalse = new Ident("@nil");
    }
    return new Call(new Ident("@if"), [cond[0], iftrue, iffalse]);
}

/// reads first element of postfix expression
alias readPostExpr = Spanning!readPostExprImpl;
Node readPostExprImpl(ref TokenArray tokens)
{
    Node last = void;
    if (tokens[0].isKeyword("lambda"))
    {
        tokens.nextIs(Token.Type.keyword, "lambda");
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
        tokens.nextIs(Token.Type.keyword, "if");
        last = tokens.readIf;
    }
    else if (tokens[0].isKeyword("scope"))
    {
        tokens.nextIs(Token.Type.keyword, "scope");
        Node node = tokens.readPostExpr;
        last = new Call(new Call(new Ident("@fun"), [new Call(null), node]), null);
    }
    else if (tokens[0].isKeyword("using"))
    {
        tokens.nextIs(Token.Type.keyword, "using");
        Node tab = tokens.readParens[0];
        Node then = tokens.readBlock;
        last = new Call(new Ident("@using"), [tab, then]);
    }
    else if (tokens[0].isKeyword("table"))
    {
        tokens.nextIs(Token.Type.keyword, "table");
        Node tab = new Call(new Ident("@table"), null);
        Node then = tokens.readBlock;
        last = new Call(new Ident("@using"), [tab, then]);
    }
    else if (tokens[0].isKeyword("while"))
    {
        tokens.nextIs(Token.Type.keyword, "while");
        Node cond = tokens.readParens[$ - 1];
        Node loop = tokens.readBlock;
        last = new Call(new Ident("@while"), [cond, loop]);
    }
    else if (tokens[0].isIdent)
    {
        last = new Ident(tokens[0].value);
        tokens.nextIs(Token.Type.ident);
    }
    else if (tokens[0].isString)
    {
        last = new String(tokens[0].value);
        tokens.nextIs(Token.Type.string);
    }
    return tokens.readPostExtend(last);
}

/// read prefix before postfix expression.
/// prefix is able to be +, - or *
alias readPreExpr = Spanning!readPreExprImpl;
Node readPreExprImpl(ref TokenArray tokens)
{
    if (tokens[0].isOperator)
    {
        Token op = tokens[0];
        tokens.nextIs(Token.Type.operator);
        size_t count;
        while (tokens[0].isOperator("."))
        {
            count++;
            tokens.nextIs(Token.Type.operator, ".");
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

/// hack for counting dots in an operator expression.
/// only used for readExpr
size_t[2] countDots(ref TokenArray tokens)
{
    size_t pre;
    size_t post;
    while (tokens.length != 0 && tokens[0].isOperator("."))
    {
        pre += 1;
        tokens.nextIs(Token.Type.operator, ".");
    }
    while (tokens.length != 0 && tokens[$ - 1].isOperator("."))
    {
        post += 1;
        tokens.tokens = tokens.tokens[0 .. $ - 1];
    }
    return [pre, post];
}

/// reads any expresssion, level should start at zero
alias readExpr = Spanning!readExprImpl;
Node readExprImpl(ref TokenArray tokens, size_t level)
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
        tokens.nextIsAny;
    }
    if (opers.length != 0 && opers[0].isOperator("=>"))
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

/// reads any statement ending in a semicolon
alias readStmt = Spanning!readStmtImpl;
Node readStmtImpl(ref TokenArray tokens)
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
        tokens.nextIsAny;
    }
    tokens.nextIs(Token.Type.semicolon);
    TokenArray stmtTokens = newTokenArray(stmtTokens0);
    if (stmtTokens.length == 0)
    {
        return null;
    }
    if (stmtTokens[0].isKeyword("return"))
    {
        stmtTokens.nextIs(Token.Type.keyword, "return");
        return new Call(new Ident("@return"), [stmtTokens.readExpr(0)]);
    }
    if (stmtTokens[0].isKeyword("def"))
    {
        stmtTokens.nextIs(Token.Type.keyword, "def");
        Node name = new Ident(stmtTokens[0].value);
        stmtTokens.nextIs(Token.Type.ident);
        Node[] args = stmtTokens.readParens;
        Node dobody = stmtTokens.readBlock;
        return new Call(new Ident("@def"), [new Call(name, args), dobody]);
    }
    return stmtTokens.readExpr(0);
}

/// reads many staments statement, each ending in a semicolon
/// does not read brackets surrounding
alias readBlockBody = Spanning!readBlockBodyImpl;
Node readBlockBodyImpl(ref TokenArray tokens)
{
    Node[] ret;
    while (tokens.length != 0 && !tokens[0].isClose("}"))
    {
        while (tokens.length != 0 && tokens[0].isComment)
        {
            tokens = tokens[1 .. $];
            tokens.readStmt;
        }
        if (tokens.length == 0)
        {
            break;
        }
        Node stmt = tokens.readStmt;
        if (stmt !is null)
        {
            ret ~= stmt;
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

/// parses code as the dext programming language
Node parse(string code)
{
    locs.length = 0;
    TokenArray tokens = newTokenArray(code.tokenize);
    try
    {
        Node node = tokens.readBlockBody;
        return node;
    }
    catch (Exception e)
    {
        string[] lines = code.split("\n");
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
