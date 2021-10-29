module ext.paka.parse.util;

import std.conv : to;
import std.stdio;
import std.algorithm;
import purr.srcloc;
import purr.ast.ast;
import ext.paka.parse.tokens;
import purr.err;

alias UnaryOp = Node delegate(Node rhs);
alias BinaryOp = Node delegate(Node lhs, Node rhs);

/// operators for comparrason
string[] cmpOps = ["<", ">", "<=", ">=", "==", "!="];

/// wraps a function of type Node function(T...)(TokenArray tokens, T args).
/// it gets the span of tokens consumed and it gives them a span
template Spanning(alias F, T...) {
    Node spanning(TokenArray tokens, T a) {
        string src0 = tokens.src;
        string src1 = tokens.first.span.first.src;
        Node ret = F(tokens, a);
        if (ret !is null && !ret.fixed) {
            string srcN = tokens.first.span.first.src;
            size_t diff = src1.length - srcN.length;
            ret.fixed = true;
            ret.file = tokens.first.span.first.file;
            ret.src = src1[0 .. diff].strip(' ').strip('\n').strip('\t');
            ret.offset = src0.length - src1.length;
        }
        return ret;
    }

    alias Spanning = spanning;
}

// version = tokenize_at_once;

/// token reader.
class TokenArray {
    Token first;
    SrcLoc position;
    string src;

    this(SrcLoc pos) {
        src = pos.src;
        position = pos;
        skip;
    }

    void strip() {
        position.stripToken;
    }

    /// this just skips a token, often used for bracket matching
    void skip() {
        first = position.readToken;
    }

    TokenArray dup() {
        return new TokenArray(position);
    }

    /// wraps match, it throws a nice error when it does not match
    void nextIs(Token...)(Token a) {
        if (!match(a)) {
            vmFail("expected " ~ a[$ - 1].to!string ~ " got " ~ first.to!string);
        }
    }

    /// consumes token if it is of type, returns weather it was consumed
    private bool match(Token.Type type) {
        if (first.type == type) {
            skip;
            return true;
        }
        return false;
    }

    /// consumes token matching the args, returns weather it was consumed
    private bool match(Token.Type type, string val) {
        if (first.type == type && first.value == val) {
            skip;
            return true;
        }
        return false;
    }
}
