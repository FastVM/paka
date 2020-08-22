module lang.tokens;

import std.ascii;
import std.conv;
import std.algorithm;
import std.array;
import std.stdio;

enum string[][] prec = [
        ["+=", "*=", "/=", "%=", "-=", "="], ["=>"], ["||", "&&"],
        ["<=", ">=", "<", ">", "!=", "=="], ["+", "-"], ["*", "/", "%"]
    ];

enum string[] nops = [".", "::", "*", "!", ",", ":"];

enum string[] keywords = [
        "if", "else", "while", "return", "def", "target", "lambda", "using",
        "table"
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
    this(T)(Type t, T v = null)
    {
        type = t;
        value = cast(string) v;
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

Token readToken(ref string code)
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

    if (peek == '#')
    {
        while (peek != '\n')
        {
            read;
        }
        return code.readToken;
    }
    if (peek == ';')
    {
        return Token(Token.Type.semicolon, [read]);
    }
    if (peek.isWhite)
    {
        consume;
        return Token(Token.Type.none);
    }
    if (peek == ',')
    {
        return Token(Token.Type.comma, [read]);
    }
    static foreach (i; levels)
    {
        if (code.startsWith(i))
        {
            code = code[i.length .. $];
            return Token(Token.Type.operator, i);
        }
    }
    if (peek.isAlphaNum || peek == '_' || peek == '?')
    {
        char[] ret;
        while (peek.isAlphaNum || peek == '_')
        {
            ret ~= read;
        }
        if (levels.canFind(ret))
        {
            return Token(Token.Type.operator, ret);
        }
        if (keywords.canFind(ret))
        {
            return Token(Token.Type.keyword, ret);
        }
        return Token(Token.Type.ident, ret);
    }
    if ("{[(".canFind(peek))
    {
        return Token(Token.Type.open, [read]);
    }
    if ("}])".canFind(peek))
    {
        return Token(Token.Type.close, [read]);
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
        return Token(Token.Type.string, ret);
    }
    throw new Exception("bad char " ~ peek);
}

Token[] tokenize(string code)
{
    Token[] tokens;
    while (code.length > 0)
    {
        Token token = code.readToken;
        if (token.type == Token.Type.none)
        {
            continue;
        }
        tokens ~= token;
    }
    tokens ~= Token(Token.type.semicolon);
    return tokens;
}
