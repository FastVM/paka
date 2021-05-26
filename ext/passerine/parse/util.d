module ext.passerine.parse.util;

import std.conv;
import purr.srcloc;
import purr.dynamic;
import purr.ast.ast;
import ext.passerine.tokens;

alias UnaryOp = Node delegate(Node rhs);
alias BinaryOp = Node delegate(Node lhs, Node rhs);

/// safe array of tokens
alias TokenArray = PushArray!Token;

/// operators for comparrason
string[] cmpOps = ["<", ">", "<=", ">=", "==", "!="];

/// locations for error handling
SrcLoc[] locs;

/// context for static expressions
size_t[] staticCtx;

/// wraps a function of type Node function(T...)(TokenArray tokens, T args).
/// it gets the span of tokens consumed and it gives them a span
template Spanning(alias F, T...)
{
    Node spanning(ref TokenArray tokens, T a)
    {
        TokenArray orig = tokens;
        bool doLocs = orig.length != 0;
        if (doLocs && orig.length != 0)
        {
            locs ~= orig[0].span.last;
        }
        scope (success)
        {
            if (doLocs && orig.length != 0)
            {
                locs.length--;
            }
        }
        Node ret = F(tokens, a);
        if (orig.length != 0 && ret !is null)
        {
            if (tokens.length == 0)
            {
                ret.span = Span(orig[0].span.first.dup, orig[$ - 1].span.last.dup);
            }
            else
            {
                ret.span = Span(orig[0].span.first.dup, tokens.first.span.first.dup);
            }
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

    /// utils that only happens if the token is a token array
    static if (is(T == Token))
    {
        void eat()
        {
            while (this.length != 0 && this[0].type == Token.Type.semicolon)
            {
                tokens = tokens[1 .. $];
            }
        }

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
            if (this[0].value == val)
            {
                return match(type);
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

        Token first()
        {
            return tokens[0];
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
    if (tokens.length == 0 || tokens.first.value != name)
    {
        throw new Exception("parse error: got " ~ tokens.first.value ~ " found " ~ name);
    }
}

// TODO: replace with TokenArray calls
/// constructs a token array, this will soon be replaced
TokenArray newTokenArray(Token[] a)
{
    return TokenArray(a);
}
