module quest.parse;

import std.conv;
import std.array;
import std.algorithm;
import lang.srcloc;
import lang.walk;
import lang.ast;
import quest.tokens;

/// safe array of tokens
alias TokenArray = PushArray!Token;

/// operators for comparrason
enum string[] cmpOps = ["<", ">", "<=", ">=", "==", "!="];

/// locations for error handling
Location[] locs;

size_t pdepth = 0;

/// wraps a function of type Node function(T...)(TokenArray tokens, T args).
/// it gets the span of tokens consumed and it gives them a span
template Spanning(alias F, T...)
{
    Node spanning(ref TokenArray tokens, T a)
    {
        TokenArray orig = tokens;
        if (orig.length != 0)
        {
            locs ~= orig[0].span.last;
        }
        scope (success)
        {
            if (orig.length != 0)
            {
                locs.length--;
            }
        }
        Node ret = F(tokens, a);
        if (orig.length > 0 && orig.length - tokens.length - 1 >= 0 && orig.length - tokens.length - 1 < orig.length && ret !is null)
        {
            ret.span = Span(orig[0].span.first, orig[orig.length - tokens.length - 1].span.last);
        }
        return ret;
    }

    alias Spanning = spanning;
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
    else
    {
        PushArray!T opSlice(size_t i, size_t j)
        {
            if (j < i || tokens.length < j)
            {
                throw new Exception("parse error 2");
            }
            return PushArray(tokens[i .. j]);
        }
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

void stripNewlines(ref TokenArray tokens)
{
    while (tokens.length != 0 && tokens[0].isEol)
    {
        tokens.nextIs(Token.Type.eol);
    }
}

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
    }
    tokens.match(Token.Type.close, [v[1]]);
    return args;
}

alias readParens = readOpen!"()";
alias readSquare = readOpen!"[]";
alias readBrace = readOpen!"{}";

alias readPreExpr = Spanning!readPreExprImpl;
Node readPreExprImpl(ref TokenArray tokens)
{
    if (tokens[0].isOperator)
    {
        Token op = tokens[0];
        tokens.nextIs(Token.Type.operator);
        string val = op.value;
        Node ret = new Call(new Ident(val), [tokens.readPreExpr]);
        return ret;
    }
    return tokens.readPostExpr;
}

alias readPostExtend = Spanning!(readPostExtendImpl, Node);
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
        ret = new Call(new Ident("@quest.call"), last ~ args);
    }
    else if (tokens[0].isOpen("["))
    {
        ret = new Call(new Ident("@quest.index"), last ~ tokens.readSquare);
    }
    else if (tokens[0].isOperator("."))
    {
        tokens.nextIs(Token.Type.operator, ".");
        Node strv = void;
        if (tokens[0].isString || tokens[0].isIdent) {
            strv = new Call(new Ident("@quest.string"), [new String(tokens[0].value)]);
            tokens.nextIsAny;
        }
        else if (tokens[0].isNumber)
        {
            strv = new Call(new Ident("@quest.number"), [new Ident(tokens[0].value)]);
            tokens.nextIsAny;
        }
        else if (tokens[0].isOpen("("))
        {
            strv = tokens.readParens[0];
        }
        else {
            throw new Exception("cannot parse dot epxression");
        }
        ret = new Call(new Ident("@quest.dot"), [last, strv]);
    }
    else if (tokens[0].isOperator("::"))
    {
        tokens.nextIs(Token.Type.operator, "::");
        Node strv = void;
        if (tokens[0].isString || tokens[0].isIdent) {
            strv = new Call(new Ident("@quest.string"), [new String(tokens[0].value)]);
            tokens.nextIsAny;
        }
        else if (tokens[0].isNumber)
        {
            strv = new Call(new Ident("@quest.number"), [new Ident(tokens[0].value)]);
            tokens.nextIsAny;
        }
        else if (tokens[0].isOpen("("))
        {
            strv = tokens.readParens[0];
        }
        else {
            throw new Exception("cannot parse dot epxression");
        }
        ret = new Call(new Ident("@quest.colons"), [last, strv]);
    }
    else
    {
        return last;
    }
    return tokens.readPostExtend(ret);
}

alias readPostExpr = Spanning!readPostExprImpl;
Node readPostExprImpl(ref TokenArray tokens)
{
    Node last = void;
    if (tokens[0].isOpen("("))
    {
        last = tokens.readParens[0];
    }
    else if (tokens[0].isOpen("["))
    {
        last = new Call(new Ident("@quest.array"), tokens.readSquare);
    }
    else if (tokens[0].isOpen("{"))
    {
        last = tokens.readBlock;
    }
    else if (tokens[0].isIdent)
    {
        if (tokens[0].value != "null")
        {
            last = new Call(new Ident("@quest.load"), [new Ident(tokens[0].value)]);
        }
        else
        {
            last = new Call(new Ident("@quest.null"), [new Ident(tokens[0].value)]);
        }
        tokens.nextIs(Token.Type.ident);
    }
    else if (tokens[0].isString)
    {
        last = new Call(new Ident("@quest.string"), [new String(tokens[0].value)]);
        tokens.nextIs(Token.Type.string);
    }
    else if (tokens[0].isScope)
    {
        last = new Call(new Ident("@quest.colon"), [new Ident(tokens[0].value)]);
        tokens.nextIs(Token.Type.scope_);
    }
    else if (tokens[0].isNumber)
    {
        last = new Call(new Ident("@quest.number"), [new Ident(tokens[0].value)]);
        tokens.nextIs(Token.Type.number);
    }
    else
    {
        throw new Exception("parse error");
    }
    return tokens.readPostExtend(last);
}

alias readExpr = Spanning!(readExprImpl, size_t);
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
            if (token.isComma)
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
        lastIsOp = token.isOperator;
        tokens.nextIsAny;
    }
    Node ret = sub[0].readExpr(level + 1);
    foreach (i, v; opers)
    {
        switch (v.value)
        {
        case "<=>":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@quest.cmp"), [ret, rhs]);
            break;
        case "<":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@quest.lt"), [ret, rhs]);
            break;
        case ">":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@quest.gt"), [ret, rhs]);
            break;
        case "<=":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@quest.lte"), [ret, rhs]);
            break;
        case ">=":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@quest.gte"), [ret, rhs]);
            break;
        case "==":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@quest.eq"), [ret, rhs]);
            break;
        case "!=":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@quest.neq"), [ret, rhs]);
            break;
        case "+":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@quest.add"), [ret, rhs]);
            break;
        case "-":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@quest.sub"), [ret, rhs]);
            break;
        case "*":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@quest.mul"), [ret, rhs]);
            break;
        case "/":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@quest.div"), [ret, rhs]);
            break;
        case "%":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@quest.mod"), [ret, rhs]);
            break;
        case "=":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@quest.set.to"), [ret, rhs]);
            break;
        case "+=":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@quest.set.add"), [ret, rhs]);
            break;
        case "-=":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@quest.set.sub"), [ret, rhs]);
            break;
        case "*=":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@quest.set.mul"), [ret, rhs]);
            break;
        case "/=":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@quest.set.div"), [ret, rhs]);
            break;
        case "%=":
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident("@quest.set.mod"), [ret, rhs]);
            break;
        default:
            Node rhs = sub[i + 1].readExpr(level + 1);
            ret = new Call(new Ident(v.value), [ret, rhs]);
            if (cmpOps.canFind(v.value))
            {
                if (opers.length != 1)
                {
                    throw new Exception("cannot chain operator");
                }
            }
            break;
        }
    }
    return ret;
}

alias readStmt = Spanning!readStmtImpl;
Node readStmtImpl(ref TokenArray tokens)
{
    Token[] stmtTokensRaw;
    size_t depth;
    while (tokens.length != 0)
    {
        if (tokens[0].isOpen)
        {
            depth++;
        }
        if (tokens[0].isClose)
        {
            depth--;
        }
        if (!tokens[0].isEol)
        {
            stmtTokensRaw ~= tokens[0];
        }
        else if (depth == 0) {
            tokens.nextIs(Token.Type.eol);
            break;
        }
        else {
            stmtTokensRaw ~= tokens[0];
        }
        tokens.nextIsAny;
    }
    TokenArray stmtTokens = TokenArray(stmtTokensRaw);
    if (stmtTokens.length == 0)
    {
        return null;
    }
    return stmtTokens.readExpr(0);
}

alias readBlockBody = Spanning!readBlockBodyImpl;
Node readBlockBodyImpl(ref TokenArray tokens)
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

alias readBlock = Spanning!readBlockImpl;
Node readBlockImpl(ref TokenArray tokens)
{
    tokens.nextIs(Token.Type.open, "{");
    Node ret = readBlockBody(tokens);
    if (tokens.length != 0 && tokens[0].isClose("}"))
    {
        tokens.nextIs(Token.Type.close, "}");
    }
    return new Call(new Ident("@quest.block"), (cast(Call) ret).args[1..$]);
}

Node parse(string code)
{
    TokenArray tokens = TokenArray(code.tokenize);
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
    assert(0);
}
