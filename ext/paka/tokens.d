module paka.tokens;

import std.ascii;
import std.conv;
import std.algorithm;
import std.array;
import purr.io;
import purr.srcloc;

/// operator precidence
enum string[][] prec = [
        ["+=", "~=", "*=", "/=", "%=", "-=", "="], ["|>", "<|"], ["=>"], ["||",
            "&&"], ["<=", ">=", "<", ">", "!=", "=="], ["+", "-", "~"], [
            "*", "/", "%"
        ]
    ];

/// operators that dont work like binary operators sometimes
enum string[] nops = [".", "!", ",", ":"];

/// language keywords
enum string[] keywords = [
        "if", "else", "while", "return", "def", "lambda","assert",
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
        /// string template literal
        format,
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
        if (code.length == 0)
        {
            return;
        }
        if (code[0] == '\n')
        {
            location.line += 1;
            location.column = 1;
        }
        else
        {
            location.column += 1;
        }
        code = code[1 .. $];
    }

    char read()
    {
        char ret = peek;
        consume;
        return ret;
    }

    Location begin = location;

    Token consToken(T)(Token.Type t, T v)
    {
        Location end = location.dup;
        Span span = Span(begin, end);
        return Token(span, t, v);
    }

    if (peek == '#')
    {
        while (code.length != 0 && peek != '\n')
        {
            consume;
        }
        return code.readToken(location);
    }
    if (peek.isWhite)
    {
        consume;
        return consToken(Token.Type.none, " ");
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
            foreach (_; 0..i.length)
            {
                consume;
            }
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
        char got = read;
        char[] ret;
        while (peek != '"')
        {
            got = read;
            if (got == '\\')
            {
                switch (got = read)
                {
                case 'n':
                    ret ~= '\n';
                    break;
                case '"':
                    ret ~= '"';
                    break;
                case 'r':
                    ret ~= '\n';
                    break;
                case 't':
                    ret ~= '\t';
                    break;
                case 's':
                    ret ~= ' ';
                    break;
                case 'f':
                    goto case;
                case 'u':
                    ret ~= '\\';
                    ret ~= got;
                    while (got != '}')
                    {
                        got = read;
                        if (got == '\0')
                        {
                            throw new Exception("parse error: end of file with unclosed string");
                        }
                        ret ~= got;
                    }
                    ret ~= '\\';
                    break;
                default:
                    throw new Exception("parse error: unknown escape '" ~ got ~ "'");
                }
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
    throw new Exception("parse error: bad char " ~ peek);
}

/// repeatedly calls a readToken until its empty
Token[] tokenize(Location location)
{
    string code = location.src;
    Token[] tokens;
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
