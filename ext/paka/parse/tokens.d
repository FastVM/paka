module ext.paka.parse.tokens;

import std.ascii;
import std.conv : to;
import std.algorithm;
import std.array;
import purr.srcloc;
import purr.err;

/// operator precidence
string[][] prec = [
    ["::"], ["->"], ["+=", "~=", "*=", "/=", "%=", "-=", "="], ["|>", "<|"],
    ["or", "and"], ["<=", ">=", "<", ">", "!=", "=="], ["+", "-"], [
        "*", "/", "%"
    ]
];

/// operators that dont work like binary operators sometimes
string[] nops = [".", "not", ",", "\\", "!", "#", ":", "..."];

/// language keywords
string[] keywords = [
    "if", "else", "def", "lambda", "import", "true", "false", "nil", "table",
    "while", "static", "return"
];

/// gets the operators by length not precidence
string[] levels() {
    return join(prec ~ nops).sort!"a.length > b.length".array;
}

version = nanorc;

Token.Type[] noFollow = [Token.Type.ident, Token.Type.string, Token.Type.format];

/// simple token
struct Token {
    /// the type of the token
    enum Type {
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
pragma(inline, true):
    this(T)(Span s, Type t, T v = null) {
        type = t;
        value = cast(string) v;
        span = s;
    }

    /// shows token along with location
    string toString() {
        return span.pretty ~ " -> \"" ~ value ~ "\"";
    }

    bool exists() {
        return type != Type.none;
    }

    bool isIdent() {
        return type == Type.ident;
    }

    bool isString() {
        return type == Type.string;
    }

    bool isKeyword(string name) {
        return type == Type.keyword && name == value;
    }

    bool isKeyword() {
        return type == Type.keyword;
    }

    bool isOperator(string name) {
        return type == Type.operator && name == value;
    }

    bool isOperator() {
        return type == Type.operator;
    }

    bool isOpen(string name) {
        return type == Type.open && name == value;
    }

    bool isOpen() {
        return type == Type.open;
    }

    bool isClose(string name) {
        return type == Type.close && name == value;
    }

    bool isClose() {
        return type == Type.close;
    }

    bool isSemicolon() {
        return type == Type.semicolon;
    }

    bool isComma() {
        return type == Type.comma;
    }
}

/// reads a single token from a string
Token readToken(ref SrcLoc location) {
    ref string code() {
        return location.src;
    }

    char peek() {
        if (code.length == 0) {
            return '\0';
        }
        return code[0];
    }

    void consume() {
        if (code.length == 0) {
            return;
        }
        if (code[0] == '\n') {
            location.line += 1;
            location.column = 1;
        } else {
            location.column += 1;
        }
        code = code[1 .. $];
    }

    char read() {
        char ret = peek;
        consume;
        return ret;
    }

    SrcLoc begin = location;

    Token consToken(T)(Token.Type t, T v) {
        SrcLoc end = location.dup;
        Span span = Span(begin, end);
        return Token(span, t, v);
    }

redo:
    if (peek == '#' && code.length >= 2 && code[1] == '#') {
        while (code.length != 0 && peek != '\n') {
            consume;
        }
        goto redo;
    }
    if (peek.isWhite) {
        consume;
        goto redo;
    }
    if (peek == ';') {
        return consToken(Token.Type.semicolon, [read]);
    }
    if (peek == ',') {
        return consToken(Token.Type.comma, [read]);
    }
    foreach (i; levels) {
        if (code.startsWith(i) && !i[$ - 1].isAlphaNum) {
            foreach (_; 0 .. i.length) {
                consume;
            }
            return consToken(Token.Type.operator, i);
        }
    }
    if (peek.isAlphaNum || peek == '_' || peek == '@' || peek == '?') {
        bool isNumber = true;
        char[] ret;
        while (peek.isAlphaNum || peek == '_' || peek == '@' || peek == '?'
                || (isNumber && peek == '.')) {
            isNumber = isNumber && (peek.isDigit || peek == '.');
            ret ~= read;
        }
        if (levels.canFind(ret)) {
            return consToken(Token.Type.operator, ret);
        }
        if (keywords.canFind(ret)) {
            return consToken(Token.Type.keyword, ret);
        }
        return consToken(Token.Type.ident, ret);
    }
    if ("{[(".canFind(peek)) {
        return consToken(Token.Type.open, [read]);
    }
    if ("}])".canFind(peek)) {
        return consToken(Token.Type.close, [read]);
    }
    if (peek == '"') {
        char got = read;
        char[] ret;
        while (peek != '"') {
            got = read;
            if (got == '\\') {
                switch (got = read) {
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
                    // case 'f':
                    //     goto case;
                    // case 'u':
                    //     ret ~= '\\';
                    //     ret ~= got;
                    //     while (got != '}')
                    //     {
                    //         got = read;
                    //         if (got == '\0')
                    //         {
                    //             vmError("parse error: end of file with unclosed string");
                    //         }
                    //         ret ~= got;
                    //     }
                    //     ret ~= '\\';
                    //     break;
                default:
                    vmError("parse error: unknown escape '" ~ got ~ "'");
                }
            } else {
                ret ~= got;
            }
            if (code.length == 0) {
                vmError("parse error: end of file found in string");
            }
        }
        consume;
        return consToken(Token.Type.string, ret);
    }
    if (peek == '\0') {
        return consToken(Token.Type.none, "");
    }
    vmError("parse error: bad char " ~ peek ~ "(code: " ~ to!string(cast(ubyte) peek) ~ ")");
    assert(false);
}
