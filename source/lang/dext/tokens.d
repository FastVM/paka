module lang.dext.tokens;

import std.ascii;
import std.conv;
import std.algorithm;
import std.array;
import std.stdio;
import lang.srcloc;

/// operator precidence
enum string[][] prec = [
        ["+=", "*=", "/=", "%=", "-=", "="], ["|>", "<|"], ["=>"], ["||",
            "&&"], ["<=", ">=", "<", ">", "!=", "=="], ["+", "-"], [
            "*", "/", "%"
        ]
    ];

/// operators that dont work like binary operators sometimes
enum string[] nops = [".", "*", "!", ",", ":"];

/// language keywords
enum string[] keywords = [
        "if", "else", "while", "return", "def", "lambda", "using", "table",
        "scope",
    ];

/// gets the operators by length not precidence
enum string[] levels()
{
    return join(prec ~ nops).sort!"a.length > b.length".array;
}

/// simple token
struct Token
{
    /// the type of the token
    enum Type
    {
        /// invalid token
        none,
        /// some operator, not keyword
        operator,
        /// semicolon seperator
        semicolon,
        /// comma seperator
        comma,
        /// ident can be either a name or number
        ident,
        /// language keyword
        keyword,
        /// "[", "{", or "("
        open,
        /// "]", "}", or ")"
        close,
        /// string literal
        string,
        /// syntax comment beginning
        comment,
    }

    Type type;
    string value;
    /// where is the token
    Span span;
    /// only constructor
    this(T)(Span s, Type t, T v = null)
    {
        type = t;
        value = cast(string) v;
        span = s;
    }

    /// shows token along with location
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

    bool isComment()
    {
        return type == Type.comment;
    }
}

/// reads a single token from a string
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
        consume;
        if (peek == '#')
        {
            consume;
            return consToken(Token.Type.comment, "##");
        }
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
    if (peek.isAlphaNum || peek == '_' || peek == '$' || peek == '@')
    {
        bool isNumber = true;
        char[] ret;
        while (peek.isAlphaNum || peek == '_' || peek == '$' || peek == '@'
                || (isNumber && peek == '.'))
        {
            isNumber = isNumber && (peek.isDigit || peek == '.');
            if (peek != '@')
            {
                ret ~= read;
            }
            else
            {
                consume;
                ret ~= '.';
            }
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

/// repeatedly calls a readToken until its empty
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
