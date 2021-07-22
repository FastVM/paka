module ext.passerine.tokens;

import std.ascii;
import std.conv;
import std.algorithm;
import std.array;
import std.stdio;
import purr.srcloc;

/// operator precidence
string[][] prec = [
    ["="], ["->"], ["|"], ["..", ":"], ["and", "or"],
    ["<", ">", "<=", ">=", "==", "!="], ["+", "-", "++"], ["*", "/", "%"], ["."]
];

/// operators that dont work like binary operators sometimes
string[] nops = [",", "'", "::"];

/// language keywords
string[] keywords = ["magic"];

/// gets the operators by length not precidence
string[] levels() {
    return join(prec ~ nops).sort!"a.length > b.length".array;
}

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
    }

    Type type;
    string value;
    /// where is the token
    Span span;
    /// only constructor
    this(T)(Span s, Type t, T v = null) {
        type = t;
        value = cast(string) v;
        span = s;
    }

    /// shows token along with location
    string toString() {
        // return span.pretty ~ " -> \"" ~ value ~ "\"";
        return "\"" ~ value ~ "\"";
    }

    bool isIdent() {
        return type == Type.ident;
    }

    bool isIdent(string name) {
        return type == Type.ident && name == value;
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
Token readToken(ref string code, ref SrcLoc location) {
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

    if (code.startsWith("--")) {
        while (code.length != 0 && peek != '\n') {
            consume;
        }
        return code.readToken(location);
    }
    if (peek.isWhite && peek != '\n') {
        consume;
        return consToken(Token.Type.none, " ");
    }
    if (peek == ';') {
        read;
        return consToken(Token.Type.semicolon, ";");
    }
    if (peek == '\n') {
        read;
        return consToken(Token.Type.semicolon, "__newline__");
    }
    if (peek == ',') {
        return consToken(Token.Type.comma, [read]);
    }
    foreach (i; levels) {
        if (code.startsWith(i)) {
            foreach (_; 0 .. i.length) {
                consume;
            }
            return consToken(Token.Type.operator, i);
        }
    }
    if (peek.isAlphaNum || peek == '_' || peek == '$' || peek == '@' || peek == '?') {
        bool isNumber = true;
        char[] ret;
        while (peek.isAlphaNum || peek == '_' || peek == '$' || peek == '@'
                || peek == '?' || (isNumber && peek == '.')) {
            isNumber = isNumber && (peek.isDigit || peek == '.');
            if (peek != '@') {
                ret ~= read;
            } else {
                consume;
                ret ~= '.';
            }
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
        char first = read;
        char[] ret;
        while (peek != first) {
            char got = read;
            if (got == '\\') {
                switch (got = read) {
                default:
                    throw new Exception("Unknown escape code \\" ~ got);
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
                case '\\':
                    ret ~= ' ';
                    break;
                }
            } else {
                ret ~= got;
            }
            if (code.length == 0) {
                throw new Exception("parse error: end of file found in string");
            }
        }
        consume;
        return consToken(Token.Type.string, ret);
    }
    throw new Exception("parse error: bad char " ~ peek ~ "(code: " ~ to!string(
            cast(ubyte) peek) ~ ")");
}

/// repeatedly calls a readToken until its empty
Token[] tokenize(SrcLoc location) {
    string code = location.src;
    Token[] tokens;
    while (code.length > 0) {
        Token token = code.readToken(location);
        if (token.type == Token.Type.none) {
            continue;
        }
        tokens ~= token;
    }
    return tokens;
}
