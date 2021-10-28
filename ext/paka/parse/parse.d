module ext.paka.parse.parse;

import std.conv : to;
import std.file;
import std.array;
import std.utf;
import std.ascii;
import std.string;
import std.algorithm;
import std.functional;
import purr.err;
import purr.srcloc;
import purr.ast.walk;
import purr.ast.ast;
import ext.paka.parse.tokens;
import ext.paka.parse.util;
import ext.paka.parse.op;
import ext.paka.parse.map;

Node[string] macros;

/// reads open parens
Node[][] readOpen(string v)(TokenArray tokens) if (v == "()") {
    Node[][] ret;
    Node[] args;
    tokens.nextIs(Token.Type.open, [v[0]]);
    while (!tokens.first.isClose([v[1]])) {
        if (tokens.first.isSemicolon) {
            tokens.nextIs(Token.Type.semicolon);
            ret ~= args;
            args = null;
        } else {
            args ~= tokens.readExprBase;
            if (tokens.first.isComma) {
                tokens.nextIs(Token.Type.comma);
            }
        }
    }
    tokens.nextIs(Token.Type.close, [v[1]]);
    ret ~= args;
    return ret;
}

Node[] readOpen1(string v)(TokenArray tokens) if (v == "()") {
    Node[][] ret = tokens.readOpen!"()";
    if (ret.length > 1) {
        vmFail("unexpected semicolon in (...)");
    }
    return ret[0];
}

/// reads square brackets
Node[][] readOpen(string v)(TokenArray tokens) if (v == "[]") {
    Node[][] ret;
    Node[] args;
    tokens.nextIs(Token.Type.open, [v[0]]);
    while (!tokens.first.isClose([v[1]])) {
        if (tokens.first.isSemicolon) {
            tokens.nextIs(Token.Type.semicolon);
            ret ~= args;
            args = null;
        } else {
            args ~= tokens.readExprBase;
            if (tokens.first.isComma) {
                tokens.nextIs(Token.Type.comma);
            }
        }
    }
    tokens.nextIs(Token.Type.close, [v[1]]);
    ret ~= args;
    return ret;
}

/// reads open curly brackets
Node[] readOpen(string v)(TokenArray tokens) if (v == "{}") {
    Node[] args;
    tokens.nextIs(Token.Type.open, [v[0]]);
    size_t items = 0;
    while (!tokens.first.isClose([v[1]])) {
        args ~= tokens.readExprBase;
        items++;
        if (tokens.first.isComma) {
            tokens.nextIs(Token.Type.comma);
        }
    }
    tokens.nextIs(Token.Type.close, [v[1]]);
    return args;
}

/// strips newlines and changes the input
void stripNewlines(TokenArray tokens) {
    while (tokens.first.isSemicolon) {
        tokens.nextIs(Token.Type.semicolon);
    }
}

Node readPostCallExtend(TokenArray tokens, Node last) {
    Node[][] args = tokens.readOpen!"()";
    while (tokens.first.isOperator("->")) {
        tokens.nextIs(Token.Type.operator, "->");
        Node[] params;
        while (tokens.first.isIdent) {
            params ~= cast(Node) ident(tokens.first.value);
            tokens.nextIs(Token.Type.ident);
        }
        args[$ - 1] ~= new Form("lambda", [
                new Form("args", params), tokens.readBlock
                ]);
    }
    foreach (argList; args) {
        last = last.call(argList);
    }
    return last;
}

/// after reading a small expression, read a postfix expression
alias readPostExtend = Spanning!(readPostExtendImpl, Node);
Node readPostExtendImpl(TokenArray tokens, Node last) {
    if (!tokens.first.exists) {
        return last;
    }
    if (tokens.first.isOpen("(")) {
        return tokens.readPostExtend(tokens.readPostCallExtend(last));
    } else if (tokens.first.isOpen("[")) {
        Node[][] arg = tokens.readOpen!"[]";
        if (arg.length != 1) {
            vmError("semicolon not valid in index");
        }
        Node cur = new Form("index", last, arg[0]);
        return tokens.readPostExtend(cur);
    } else if (tokens.first.isOperator(".")) {
        tokens.nextIs(Token.Type.operator, ".");
        Node index = new Value(tokens.first.value);
        tokens.nextIs(Token.Type.ident);
        Node[] args = [last];
        if (tokens.first.isOpen("(")) {
            args ~= tokens.readOpen1!"()";
        }
        return tokens.readPostExtend(index.call(args));
    } else {
        return last;
    }
}

/// read an if statement
alias readIf = Spanning!readIfImpl;
Node readIfImpl(TokenArray tokens) {
    Node cond = tokens.readExprBase;
    Node iftrue = tokens.readBlock;
    Node iffalse;
    if (tokens.first.isKeyword("else")) {
        tokens.nextIs(Token.Type.keyword, "else");
        iffalse = tokens.readBlock;
    } else {
        iffalse = Value.empty;
    }
    return new Form("if", cond, iftrue, iffalse);
}
/// read an if statement
alias readWhile = Spanning!readWhileImpl;
Node readWhileImpl(TokenArray tokens) {
    Node cond = tokens.readExprBase;
    Node block = tokens.readBlock;
    return new Form("while", cond, block);
}
/// read an if statement
alias readUntil = Spanning!readUntilImpl;
Node readUntilImpl(TokenArray tokens) {
    Node cond = tokens.readExprBase;
    Node block = tokens.readBlock;
    return new Form("until", cond, block);
}

void skip1(ref string str, ref Span span) {
    if (str[0] == '\n') {
        span.first.line += 1;
        span.first.column = 1;
    } else {
        span.first.column += 1;
    }
    str = str[1 .. $];
}

bool isDigitInBase(char c, long base) {
    if (base > 0 && base < 10) {
        return c - '0' < base;
    }
    if (base == 10) {
        return c.isDigit;
    }
    if (base > 10) {
        long val = c;
        if (val >= 'A' && val <= 'A') {
            val = val - 'A' + 'a';
        }
        bool isLetterDigit = val >= 10 && val < base;
        return isLetterDigit || c.isDigitInBase(10);
    }
    vmFail("base not valud: " ~ base.to!string);
    assert(false);
}

long parseNumberOnly(ref string input, size_t base) {
    string str;
    while (input.length != 0 && input[0].isDigitInBase(base)) {
        str ~= input[0];
        input = input[1 .. $];
    }
    if (str.length == 0) {
        vmFail("found no digits when parse escape in base " ~ base.to!string);
    }
    return str.to!size_t(cast(uint) base);
}

size_t escapeNumber(ref string input) {
    if (input[0] == '0') {
        char ctrlchr = input[1];
        input = input[2 .. $];
        switch (ctrlchr) {
        case 'b':
            return input.parseNumberOnly(2);
        case 'o':
            return input.parseNumberOnly(8);
        case 'n':
            size_t base = input.escapeNumber;
            if (input.length < 1 || input[0] != ':') {
                string why = "0n" ~ base.to!string ~ " must be followd by a colon (:)";
                vmFail("cannot have escape: " ~ why);
            }
            input = input[1 .. $];
            if (base == 1) {
                size_t num;
                while (input.length != 0 && input[0] == '0') {
                    num++;
                }
                return num;
            }
            if (base > 36) {
                string why = "0n must be followed by a number 1 to 36 inclusive";
                vmFail("cannot have escape: " ~ why);
            }
            return input.parseNumberOnly(base);
        case 'x':
            return input.parseNumberOnly(16);
        default:
            string why = "0 must be followed by one of: nbox";
            vmFail("cannot have escape: " ~ why);
            assert(false);
        }
    } else {
        return input.parseNumberOnly(10);
    }
}

/// reads first element of postfix expression
alias readPostExpr = Spanning!readPostExprImpl;
Node readPostExprImpl(TokenArray tokens) {
    Node last = void;
    if (tokens.first.isKeyword("lambda")) {
        tokens.nextIs(Token.Type.keyword, "lambda");
        if (tokens.first.isOpen("(")) {
            last = new Form("lambda", [
                    new Form("args", tokens.readOpen1!"()"), tokens.readBlock
                    ]);
        } else if (tokens.first.isOpen("{") || tokens.first.isOperator(":")) {
            last = new Form("lambda", new Form("args"), tokens.readBlock);
        }
    } else if (tokens.first.isOpen("(")) {
        Node[] nodes = tokens.readOpen1!"()";
        if (nodes.length != 1) {
            vmFail("no tuples yet");
        }
        last = nodes[0];
    } else if (tokens.first.isOpen("[")) {
        Node[][] nodes = tokens.readOpen!"[]";
        Node ret = new Form("array", nodes[$ - 1]);
        foreach_reverse (node; nodes[0 .. $ - 1]) {
            ret = new Form("array", node, ret);
        }
        last = ret;
    } else if (tokens.first.isKeyword("if")) {
        tokens.nextIs(Token.Type.keyword, "if");
        last = tokens.readIf;
    } else if (tokens.first.isKeyword("throw")) {
        tokens.nextIs(Token.Type.keyword, "throw");
        last = new Form("throw", tokens.readExprBase);
    } else if (tokens.first.isKeyword("while")) {
        tokens.nextIs(Token.Type.keyword, "while");
        last = tokens.readWhile;
    } else if (tokens.first.isKeyword("until")) {
        tokens.nextIs(Token.Type.keyword, "until");
        last = tokens.readUntil;
    } else if (tokens.first.isKeyword("true")) {
        tokens.nextIs(Token.Type.keyword, "true");
        last = new Value(true);
    } else if (tokens.first.isKeyword("map")) {
        tokens.nextIs(Token.Type.keyword, "map");
        if (tokens.first.isOpen("(")) {
            last = new Form("do", tokens.readOpen1!"()");
        } else {
            last = new Form("map");
        }
        if (tokens.first.isOpen("{") || tokens.first.isOperator(":")) {
            Node thisVar = new Ident("this");
            Node setThisVar = new Form("var", thisVar, last);
            Node block = tokens.readBlock;
            last = new Form("do", setThisVar, block, thisVar);
        }
        return last;
    } else if (tokens.first.isKeyword("none")) {
        tokens.nextIs(Token.Type.keyword, "none");
        last = new Value(null);
    } else if (tokens.first.isKeyword("false")) {
        tokens.nextIs(Token.Type.keyword, "false");
        last = new Value(false);
    } else if (tokens.first.isKeyword("nil")) {
        tokens.nextIs(Token.Type.keyword, "nil");
        last = new Form("array");
    } else if (tokens.first.isKeyword("self")) {
        tokens.nextIs(Token.Type.keyword, "self");
        last = new Form("capture");
    } else if (tokens.first.isIdent) {
        if (tokens.first.value.all!isDigit) {
            last = new Value(tokens.first.value.to!double);
            tokens.nextIs(Token.Type.ident);
        } else if (Node* retRef = tokens.first.value in macros) {
            last = *retRef;
            tokens.nextIs(Token.Type.ident);
        } else {
            last = ident(tokens.first.value);
            tokens.nextIs(Token.Type.ident);
        }
    } else if (tokens.first.isString) {
        last = new Value(tokens.first.value);
        tokens.nextIs(Token.Type.string);
    } else {
        vmError("expected something else in parser");
    }
    return tokens.readPostExtend(last);
}

/// read prefix before postfix expression.
alias readPreExpr = Spanning!readPreExprImpl;
Node readPreExprImpl(TokenArray tokens) {
    if (tokens.first.isOperator) {
        string[] vals;
        while (tokens.first.isOperator) {
            vals ~= tokens.first.value;
            tokens.nextIs(Token.Type.operator);
        }
        return parseUnaryOp(vals)(tokens.readPostExpr);
    }
    if (tokens.first.isKeyword("box")) {
        tokens.nextIs(Token.type.keyword);
        Node ret = tokens.readPreExpr;
        return new Form("box", ret);
    }
    if (tokens.first.isKeyword("unbox")) {
        tokens.nextIs(Token.type.keyword);
        Node ret = tokens.readPreExpr;
        return new Form("unbox", ret);
    }
    return tokens.readPostExpr;
}

alias readExprBase = Spanning!(readExprBaseImpl);
/// reads any expression with precedence of zero
Node readExprBaseImpl(TokenArray tokens) {
    return tokens.readExpr(0);
}

bool isAnyOperator(Token tok, string[] ops) {
    foreach (op; ops) {
        if (tok.isOperator(op)) {
            return true;
        }
    }
    return false;
}

alias readExpr = Spanning!(readExprImpl, size_t);
/// reads any expression
Node readExprImpl(TokenArray tokens, size_t level) {
    if (level == prec.length) {
        return tokens.readPreExpr;
    }
    string[][] opers;
    Node[] subNodes = [tokens.readExpr(level + 1)];
    while (tokens.first.isAnyOperator(prec[level])) {
        opers ~= [tokens.first.value];
        tokens.nextIs(Token.Type.operator);
        while (tokens.first.isAnyOperator(["<", ">"])) {
            opers[$ - 1] ~= tokens.first.value;
            tokens.nextIs(Token.Type.operator);
            opers[$ - 1] ~= tokens.first.value;
            tokens.nextIs(Token.Type.operator);
        }
        subNodes ~= tokens.readExpr(level + 1);
    }
    Node ret = subNodes[0];
    Ident last;
    foreach (i, oper; opers) {
        ret = parseBinaryOp(oper)(ret, subNodes[i + 1]);
    }
    return ret;
}

/// reads any statement ending in a semicolon
alias readStmt = Spanning!readStmtImpl;
Node readStmtImpl(TokenArray tokens) {
    scope (exit) {
        while (tokens.first.isSemicolon) {
            tokens.nextIs(Token.Type.semicolon);
        }
    }
    if (tokens.first.isKeyword("handle")) {
        tokens.nextIs(Token.Type.keyword, "handle");
        Node name = tokens.readExprBase;
        Node lambdaBody = tokens.readBlock;
        Node lambda = new Form("lambda", new Form("args"), new Form("do", lambdaBody, new Form("reject", new Value(null))));
        return new Form("handle", name, lambda);
    }
    if (tokens.first.isKeyword("return")) {
        tokens.nextIs(Token.Type.keyword, "return");
        return new Form("return", tokens.readExprBase);
    }
    if (tokens.first.isKeyword("resolve")) {
        tokens.nextIs(Token.Type.keyword, "resolve");
        return new Form("resolve", tokens.readExprBase);
    }
    if (tokens.first.isKeyword("reject")) {
        tokens.nextIs(Token.Type.keyword, "reject");
        return new Form("reject", tokens.readExprBase);
    }
    if (tokens.first.isKeyword("exit")) {
        tokens.nextIs(Token.Type.keyword, "exit");
        return new Form("exit");
    }
    if (tokens.first.isKeyword("macro")) {
        tokens.nextIs(Token.Type.keyword, "macro");
        string name = tokens.first.value;
        tokens.nextIs(Token.Type.ident);
        macros[name] = tokens.readBlock;
        return new Form("do");
    }
    if (tokens.first.isKeyword("jump")) {
        tokens.nextIs(Token.Type.keyword, "jump");
        return new Form("jump", tokens.readExprBase);
    }
    if (tokens.first.isKeyword("def")) {
        tokens.nextIs(Token.Type.keyword, "def");
        Node id = ident(tokens.first.value);
        tokens.skip;
        Node[][] allArgs = tokens.readOpen!"()";
        Node then = tokens.readBlock;
        // foreach_reverse (args; allArgs) {
        //     then = new Form("lambda", new Form("args", args), then);
        // }
        // return new Form("var", id, then);
        // if (Form thenForm = cast(Form) then) {
            return new Form("var", id, new Form("lambda", new Form("args", allArgs[0]), then));
        // }
        // vmFail("parse error");
    }
    return tokens.readExprBase;
}

/// reads many staments statement, each ending in a semicolon
/// does not read brackets surrounding
alias readBlockBody = Spanning!readBlockBodyImpl;
Node readBlockBodyImpl(TokenArray tokens) {
    Node[] ret;
    while (tokens.first.exists && !tokens.first.isClose("}") && !tokens.first.isKeyword("else")) {
        Node stmt = tokens.readStmt;
        if (Form form = cast(Form) stmt) {
            if (form.form == "do") {
                ret ~= form.args;
                continue;
            }
        } 
        ret ~= stmt;
    }
    if (ret.length == 1) {
        return ret[0];
    } else {
        return new Form("do", ret);
    }
}

/// wraps the readblock and consumes curly braces
alias readBlock = Spanning!readBlockImpl;
Node readBlockImpl(TokenArray tokens) {
    if (tokens.first.isOperator(":")) {
        tokens.nextIs(Token.Type.operator, ":");
        return tokens.readStmt;
    } else {
        tokens.nextIs(Token.Type.open, "{");
        Node ret = readBlockBody(tokens);
        tokens.nextIs(Token.Type.close, "}");
        return ret;
    }
}

alias parsePakaValue = parsePakaAs!readBlockBodyImpl;
alias parsePaka = parsePakaValue;
/// parses code as the paka programming language
Node parsePakaAs(alias parser)(SrcLoc loc) {
    TokenArray tokens = new TokenArray(loc);
    try {
        Node node = parser(tokens);
        return node;
    } catch (Recover e) {
        string[] lines = loc.src.split("\n");
        size_t[] nums;
        size_t ml = 0;
        foreach (i; locs) {
            if (nums.length == 0 || nums[$ - 1] < i.line) {
                nums ~= i.line;
                ml = max(ml, i.line.to!string.length);
            }
        }
        string ret;
        foreach (i; nums) {
            string s = i.to!string;
            foreach (j; 0 .. ml - s.length) {
                ret ~= ' ';
            }
            if (i > 0 && i < lines.length) {
                ret ~= i.to!string ~ ": " ~ lines[i - 1].to!string ~ "\n";
            }
        }
        e.msg = ret ~ e.msg;
        vmError(e.msg);
        assert(false);
    }
}

Node parsePrelude(SrcLoc loc) {
    return SrcLoc(1, 1, "prelude.paka", import("prelude.paka")).parsePaka;
}

Node parseRaw(SrcLoc loc) {
    return loc.parsePaka;
}

Node parse(SrcLoc loc) {
    return new Form("do", loc.parsePrelude, loc.parseRaw);
}
