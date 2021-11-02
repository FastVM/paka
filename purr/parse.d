module purr.parse;

import std.conv : to;
import purr.ast.ast: Node;
import purr.err: vmError;
import purr.srcloc: SrcLoc;

enum string bashLine = "#!";
enum string langLine = "#?";

__gshared Node function(SrcLoc code)[string] parsers;

string readLine(ref string code) {
    string ret;
    while (code.length != 0 && code[0] != '\n') {
        ret ~= code[0];
        code = code[1 .. $];
    }
    if (code.length != 0) {
        code = code[1 .. $];
    }
    return ret;
}

Node parse(SrcLoc code, string langname = "paka") {
    if (auto i = langname in parsers) {
        return (*i)(code);
    } else {
        vmError("language not found: " ~ langname);
        assert(false);
    }
}
