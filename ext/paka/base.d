module ext.paka.base;

import std.file;
import std.algorithm;
import std.conv;
import std.array;
import purr.io;
import purr.dynamic;
import purr.base;
import purr.inter;
import purr.srcloc;
import purr.fs.disk;
import ext.paka.parse.tokens;

string line(Args...)(Args args)
{
    string ret;
    static foreach (arg; args)
    {
        ret ~= arg.to!string;
    }
    ret ~= '\n';
    return ret;
}

Dynamic pakaGenNano(Args args)
{
    string[string] config = [
        "args" : "white", "keyword" : "lightblue", "operator" : "bold,white",
        "number" : "bold,lightcyan", "string" : "bold,orange", "builtin" : "white",
        "builtin.nil" : "lightcyan", "builtin.logical" : "lightcyan",
        "builtin.number" : "lightcyan", "builtin.symbol" : "lightcyan",
        "builtin.string" : "orange", "builtin.tuple" : "pink",
        "builtin.array" : "pink", "builtin.table" : "pink",
        "builtin.callable" : "lightyellow",
    ];
    if (args.length == 1)
    {
        foreach (key, value; args[0].tab)
        {
            config[key.str] = value.str;
        }
    }
    string[2][] pairs;
    Dynamic[2][] todo;
    foreach (lvl; rootBases)
    {
        foreach (pair; lvl)
        {
            todo ~= [pair.name.dynamic, pair.val];
        }
    }
    while (todo.length != 0)
    {
        Dynamic[2] pair = todo[$ - 1];
        todo.length--;
        string name = pair[0].str;
        Dynamic value = pair[1];
        final switch (value.type)
        {
        case Dynamic.Type.nil:
            pairs ~= [config["builtin.nil"], name];
            break;
        case Dynamic.Type.log:
            pairs ~= [config["builtin.logical"], name];
            break;
        case Dynamic.Type.sml:
            pairs ~= [config["builtin.number"], name];
            break;
        case Dynamic.Type.sym:
            pairs ~= [config["builtin.symbol"], name];
            break;
        case Dynamic.Type.str:
            pairs ~= [config["builtin.string"], name];
            break;
        case Dynamic.Type.tup:
            pairs ~= [config["builtin.tuple"], name];
            break;
        case Dynamic.Type.arr:
            pairs ~= [config["builtin.array"], name];
            break;
        case Dynamic.Type.tab:
            pairs ~= [config["builtin.table"], name];
            foreach (key, val; value.tab.table)
            {
                if (key.type == Dynamic.Type.str)
                {
                    todo ~= [dynamic(name ~ `\w*.\w*` ~ key.str), val];
                }
                if (key.type == Dynamic.Type.sml)
                {
                    todo ~= [dynamic(name ~ `\w*.\w*` ~ key.str), val];
                }
            }
            break;
        case Dynamic.Type.fun:
            pairs ~= [config["builtin.callable"], name];
            break;
        case Dynamic.Type.pro:
            pairs ~= [config["builtin.callable"], name];
            break;
        }
    }
    foreach (elem; keywords)
    {
        pairs ~= [config["keyword"], elem];
    }
    foreach (elem; levels)
    {
        string name;
        foreach (chr; elem)
        {
            if (`.\+*?[^]$(){}=!|:-`.canFind(chr))
            {
                name ~= `\`;
            }
            name ~= chr;
        }
        pairs ~= [config["operator"], name];
    }
    pairs.sort!(`a[1].length < b[1].length`);
    string ret;
    ret ~= line(`syntax "paka" "\.paka"`);
    ret ~= line(`linter "aspell -x -c"`);
    foreach (pair; pairs)
    {
        ret ~= line("color ", pair[0], " \"\\b", pair[1], "\\b\"");
    }
    ret ~= line(`color `, config["number"], ` "\<(\.[0-9]([0-9]*)|[0-9]+(\.)*)\>"`);
    foreach (argno; 0 .. 16)
    {
        ret ~= line(`color `, config["args"], ` "\$`, argno, `"`);
    }
    ret ~= line(`color `, config["args"], ` "args"`);
    ret ~= line(`color `, config["string"], ` start="\"" end="\""`);
    return ret.dynamic;
}

Pair[] pakalib()
{
    Pair[] ret;
    ret ~= FunctionPair!pakaGenNano("nano");
    return ret;
}

Pair[] pakaBaseLibs()
{
    Pair[] ret;
    ret.addLib("paka", pakalib);
    ret ~= Pair("this", new Table);
    return ret;
}
