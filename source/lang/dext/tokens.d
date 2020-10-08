module lang.dext.tokens;

import std.ascii;
import std.conv;
import std.algorithm;
import std.array;
import std.stdio;
import lang.srcloc;

enum string[][] prec = [
        ["+=", "*=", "/=", "%=", "-=", "="], ["=>"], ["||", "&&"],
        ["<=", ">=", "<", ">", "!=", "=="], ["+", "-"], ["*", "/", "%"]
    ];

enum string[] nops = [".", "*", "!", ",", ":"];

enum string[] keywords = [
        "if", "else", "while", "return", "def", "target", "lambda",
    ];

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
        semicolon,
        comma,
        seperator,
        ident,
        keyword,
        number,
        open,
        close,
        indent,
        string,
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

    string toString()
    {
        return span.pretty ~ " -> \"" ~ value ~ "\"";
    }

    bool isIdent()
    {
        return type == Type.ident;
    }

    bool isString()
    {
        return type == Type.string;
    }

    bool isKeyword(string name)
    {
        return type == Type.keyword && name == value;
    }

    bool isKeyword()
    {
        return type == Type.keyword;
    }

    bool isOperator(string name)
    {
        return type == Type.operator && name == value;
    }

    bool isOperator()
    {
        return type == Type.operator;
    }

    bool isOpen(string name)
    {
        return type == Type.open && name == value;
    }

    bool isOpen()
    {
        return type == Type.open;
    }

    bool isClose(string name)
    {
        return type == Type.close && name == value;
    }

    bool isClose()
    {
        return type == Type.close;
    }

    bool isSemicolon()
    {
        return type == Type.semicolon;
    }

    bool isComma()
    {
        return type == Type.comma;
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

    if (peek == '#')
    {
        while (peek != '\n')
        {
            consume;
        }
        return code.readToken(location);
    }
    if (peek.isWhite)
    {
        consume;
        return consToken(Token.Type.none);
    }
    if (peek == ';')
    {
        return consToken(Token.Type.semicolon, [read]);
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
    if (peek.isAlphaNum || peek == '_' || peek == '?')
    {
        bool isNumber = true;
        char[] ret;
        while (peek.isAlphaNum || peek == '_' || (isNumber && peek == '.'))
        {
            isNumber = isNumber && (peek.isDigit || peek == '.');
            ret ~= read;
        }
        if (levels.canFind(ret))
        {
            return consToken(Token.Type.operator, ret);
        }
        if (keywords.canFind(ret))
        {
            return consToken(Token.Type.keyword, ret);
        }
        return consToken(Token.Type.ident, ret);
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
                case 'r':
                    ret ~= '\r';
                    break;
                case 't':
                    ret ~= '\t';
                    break;
                case 's':
                    ret ~= ' ';
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
    throw new Exception("bad char " ~ peek);
}

Token[] tokenize(string code)
{
    Token[] tokens;
    Location location;
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
