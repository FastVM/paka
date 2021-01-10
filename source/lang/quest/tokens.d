module lang.quest.tokens;

import std.ascii;
import std.conv;
import std.algorithm;
import std.array;
import std.stdio;
import lang.srcloc;

// dfmt off
enum string[][] prec = [
    ["+=", "/=", "*=", "/=", "%=", "&=", "|=", "^=", "**=", "<<=", ">>=", "="], 
    ["||"], 
    ["<=>"],
    ["&&"], 
    ["==", "!="], 
    ["<", ">", "<=", ">="], 
    ["^"], 
    ["|"], 
    ["&"], 
    ["<<", ">>"], 
    ["+", "-"],
    ["*", "/", "%"],
];
// dfmt on

enum string[] nops = [".", "::", "**"];

enum string[] levels()
{
    return join(prec ~ nops).sort!"a.length > b.length".array;
}

struct Token
{
    enum Type
    {
        none,
        operator,
        comma,
        open,
        close,
        ident,
        number,
        scope_,
        string,
        eol,
    }

    Type type;
    string value;
    Span span;

    this(T)(Span s, Type t, T v = null)
    {
        type = t;
        value = cast(string) v;
        span = s;
    }

    bool isOperator()
    {
        return type == Type.operator;
    }

    bool isOperator(string op)
    {
        return isOperator && value == op;
    }

    bool isComma()
    {
        return type == Type.comma;
    }
    
    bool isIdent()
    {
        return type == Type.ident;
    }

    bool isOpen()
    {
        return type == Type.open;
    }

    bool isOpen(string kind)
    {
        return isOpen && value == kind;
    }

    bool isClose()
    {
        return type == Type.close;
    }

    bool isClose(string kind)
    {
        return isClose && value == kind;
    }

    bool isString()
    {
        return type == Type.string;
    }

    bool isScope()
    {
        return type == Type.scope_;
    }

    bool isNumber()
    {
        return type == Type.number;
    }

    bool isEol()
    {
        return type == Type.eol;
    }

    string toString()
    {
        return span.pretty ~ " -> \"" ~ value ~ "\"";
    }
}

Token readToken(ref string code, ref Location location)
{

    char peek()
    {
        if (code.length == 0)
        {
            return '\0';
        }
        return code[0];
    }

    void consume()
    {
        if (code[0] == '\n')
        {
            location.line += 1;
            location.column = 1;
        }
        else
        {
            location.column += 1;
        }
        if (code.length != 0)
        {
            code = code[1 .. $];
        }
    }

    char read()
    {
        char ret = peek;
        consume;
        return ret;
    }

    Location begin = location;

    Token consToken(T...)(T a)
    {
        return Token(Span(begin, location), a);
    }
    if (peek == '\0')
    {
        return consToken(Token.Type.eol, "(eof)");
    }
    if (peek == '#')
    {
        while (code.length != 0 && peek != '\n')
        {
            consume;
        }
        return code.readToken(location);
    }
    if (peek == ' ' || peek == '\t')
    {
        consume;
        return consToken(Token.Type.none);
    }
    if (peek == '\n' || peek == ';')
    {
        return consToken(Token.Type.eol, read == ';' ? ";" : "(eol)");
    }
    if (peek == ',')
    {
        return consToken(Token.Type.comma, [read]);
    }
    static foreach (i; levels)
    {
        if (code.startsWith(i))
        {
            code = code[i.length .. $];
            return consToken(Token.Type.operator, i);
        }
    }
    if (peek == ':')
    {
        consume;
        string val;
        while (peek.isDigit)
        {
            val ~= read;
        }
        return consToken(Token.Type.scope_, val);
    }
    if (peek.isAlpha || peek == '_' || peek == '@')
    {
        char[] ret;
        char fst = read;        
        if (fst == '@')
        {
            ret ~= "{64}";
        }
        else {
            ret ~= fst;
        }
        while (peek.isAlphaNum || peek == '_')
        {
            ret ~= read;
        }
        return consToken(Token.Type.ident, ret);
    }
    if (peek.isDigit || peek == '_')
    {
        char[] ret;
        while (peek.isDigit || peek == '_')
        {
            if (peek != '_')
            {
                ret ~= read;
            }
        }
        return consToken(Token.Type.number, ret);
    }
    if ("{[(".canFind(peek))
    {
        return consToken(Token.Type.open, [read]);
    }
    if ("}])".canFind(peek))
    {
        return consToken(Token.Type.close, [read]);
    }
    if (peek == '"')
    {
        consume;
        char[] ret;
        while (peek != '"')
        {
            char got = read;
            if (got == '\\')
            {
                switch (code[0])
                {
                case 'n':
                    ret ~= '\n';
                    break;
                case '\\':
                    ret ~= '\\';
                    break;
                case '"':
                    ret ~= '"';
                    break;
                case 'r':
                    ret ~= '\r';
                    break;
                case 't':
                    ret ~= '\t';
                    break;
                default:
                    throw new Exception("parse error: unknown escape '" ~ code[0] ~ "'");
                }
                code = code[1 .. $];
            }
            else
            {
                ret ~= got;
            }
            if (code.length == 0)
            {
                throw new Exception("parse error: end of file found in string");
            }
        }
        consume;
        return consToken(Token.Type.string, ret);
    }
    if (peek == '\'')
    {
        consume;
        char[] ret;
        while (peek != '\'')
        {
            char got = read;
            if (got == '\\')
            {
                switch (code[0])
                {
                case 'n':
                    ret ~= '\n';
                    break;
                case '\\':
                    ret ~= '\\';
                    break;
                case '"':
                    ret ~= '"';
                    break;
                case 'r':
                    ret ~= '\r';
                    break;
                case 't':
                    ret ~= '\t';
                    break;
                default:
                    throw new Exception("parse error: unknown escape '" ~ code[0] ~ "'");
                }
                code = code[1 .. $];
            }
            else
            {
                ret ~= got;
            }
            if (code.length == 0)
            {
                throw new Exception("parse error: end of file found in string");
            }
        }
        consume;
        return consToken(Token.Type.string, ret);
    }
    throw new Exception("bad char: '" ~ peek.to!byte.to!string ~ "'");
}

Token[] tokenize(string code)
{
    Token[] tokens;
    Location location = Location(1, 1);
    while (code.length > 0)
    {
        Token token = code.readToken(location);
        if (token.type == Token.Type.none)
        {
            continue;
        }
        tokens ~= token;
    }
    return tokens;
}
