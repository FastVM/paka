module ext.scheme.parser;

import std.stdio;
import std.conv;
import purr.srcloc;
import purr.ast.ast;
import purr.plugin.plugin;
import purr.plugin.plugins;

shared static this() {
    thisPlugin.addPlugin;
}

Node readExpr(ref string src) {
    while (src[0] == ' ' || src[0] == '\n') {
        src = src[1 .. $];
    }
    if (src[0] == '(') {
        src = src[1 .. $];
        Node[] children;
        while (src[0] != ')') {
            children ~= src.readExpr;
        }
        src = src[1 .. $];
        if (Ident id = cast(Ident) children[0]) {
            switch (id.repr) {
            case "println":
            case "print":
                return new Form("call", new Ident("println"), children[1 .. $]);
            case "do":
                return new Form("do", children[1 .. $]);
            case "define":
                if (Form form = cast(Form) children[1]) {
                    if (form.form == "call") {
                        return new Form("var", form.args[0], new Form("lambda",
                                new Form("args", form.args[1 .. $]),
                                new Form("do", children[2 .. $])));
                    }
                }
                return new Form("var", children[1 .. $]);
            case "lambda":
                return new Form("lambda", new Form("args", (cast(Form) children[1]).args), new Form("do", children[2..$]));
            case "false":
                return new Value(false);
            case "true":
                return new Value(true);
            case "if":
            case "+":
            case "-":
            case "*":
            case "/":
            case "<":
            case ">":
            case "<=":
            case ">=":
            case "==":
            case "!=":
                return new Form(id.repr, children[1 .. $]);
            default:
                return new Form("call", children);
            }
        }
    }
    string name;
    while (src[0] != ' ' && src[0] != '\n' && src[0] != '(' && src[0] != ')') {
        name ~= src[0];
        src = src[1 .. $];
    }
    if ('0' <= name[0] && name[0] <= '9') {
        return new Value(name.to!double);
    }
    return new Ident(name);
}

Node parseScheme(SrcLoc loc) {
    string src = "(do " ~ loc.src ~ ")";
    return src.readExpr;
}

Plugin thisPlugin() {
    Plugin plugin = new Plugin;
    plugin.parsers["scheme"] = &parseScheme;
    return plugin;
}
