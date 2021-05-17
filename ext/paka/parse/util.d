module ext.paka.parse.util;

import purr.io;
import std.conv;
import purr.srcloc;
import purr.dynamic;
import purr.ast.ast;
import ext.pakaparse.tokens;

alias UnaryOp = Node delegate(Node rhs);
alias BinaryOp = Node delegate(Node lhs, Node rhs);

/// operators for comparrason
string[] cmpOps = ["<", ">", "<=", ">=", "==", "!="];

/// locations for error handling
Location[] locs;

/// context for static expressions
size_t[] staticCtx;

/// wraps a function of type Node function(T...)(TokenArray tokens, T args).
/// it gets the span of tokens consumed and it gives them a span
template Spanning(alias F, T...)
{
    Node spanning(TokenArray tokens, T a)
    {
        Location origPos = tokens.position;
        locs ~= origPos;
        scope (success)
        {
            locs.length--;
        }
        Node ret = F(tokens, a);
        if (ret !is null)
        {
            ret.span = Span(origPos, tokens.position);
        }
        return ret;
    }

    alias Spanning = spanning;
}

// version = tokenize_at_once;

/// token reader.
class TokenArray
{
    version(tokenize_at_once)
    {
        size_t index;
        Token[] tokens;

        this(Location pos)
        {
            tokens ~= pos.readToken;
            while (tokens[$-1].exists)
            {
                tokens ~= pos.readToken;
            }
        }

        Token first()
        {
            return tokens[index];
        }

        Location position()
        {
            return first.span.first;
        }

        private void skip()
        {
            index += 1;
        }
    }
    else
    {
        Token first;
        Location position;
        this(Location pos)
        {
            position = pos;
            skip;
        }

        /// this just skips a token, often used for bracket matching
        private void skip()
        {
            first = position.readToken;
        }
    }

    TokenArray dup() {
        return new TokenArray(position);
    }

    /// wraps match, it throws a nice error when it does not match
    void nextIs(Token...)(Token a)
    {
        if (!match(a))
        {
            throw new Exception("expected " ~ a[$ - 1].to!string ~ " got " ~ first.to!string);
        }
    }

    /// consumes token if it is of type, returns weather it was consumed
    private bool match(Token.Type type)
    {
        if (first.type == type)
        {
            skip;
            return true;
        }
        return false;
    }

    /// consumes token matching the args, returns weather it was consumed
    private bool match(Token.Type type, string val)
    {
        if (first.type == type && first.value == val)
        {
            skip;
            return true;
        }
        return false;
    }
}