module ext.expr.plugin;

import purr;

shared static this()
{
    Plugin lisp = new Plugin;
    lisp.parsers["expr"] = &parser;
    lisp.addPlugin;
}

void skip(ref string code, size_t n = 1)
{
    code = code[n .. $];
}

void strip(ref string code)
{
    import std.ascii: isWhite;

    while (code[0].isWhite)
    {
        code.skip;
    }
}

enum string[string] forms = [
    "define": "set", "rec": "rec", "lambda": "fun",
    "+": "+", "-": "-", "*": "*", "/": "/", "%": "%",
    "do": "do", "if": "if", 
    "<": "<", "<=": "<=", ">": ">", ">=": ">=",
    "!=": "!=", "==": "==",
    "and": "&&", "or": "||"
];

Node read(ref string code)
{
    import std.algorithm : startsWith, canFind;

    code.strip;
    if (code[0] == '(')
    {
        code.skip;
        code.strip;
        string form = "call";
        static foreach (test, name; forms)
        {
            if (code.startsWith(test))
            {
                code.skip(test.length);
                form = name;
            }
        }
        Node[] args;
        while (code[0] != ')')
        {
            args ~= code.read;
            code.strip;
        }
        code.skip;
        return new Form(form, args);
    }
    // if (code[0] == '"')
    // {
    //     string name;
    //     code.skip;
    //     while (code[0] != '"')
    //     {
    //         name ~= code[0];
    //         code.skip;
    //     }
    //     code.skip;
    //     return new Value(name);
    // }
    string name;
    while (!"()\t\r\n ".canFind(code[0]))
    {
        name ~= code[0];
        code.skip;
    }
    switch (name)
    {
    default:
        return new Ident(name);
    case "true":
        return new Value(true);
    case "false":
        return new Value(false);
    }
}

Node parser(SrcLoc code)
{
    string src = "(do " ~ code.src ~ ")";
    return src.read;
}