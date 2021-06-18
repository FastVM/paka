module purr.inter;

import std.typecons;
import std.traits;
import purr.io;
import std.functional;
import std.conv;
import std.algorithm;
import std.meta;
import purr.ast.ast;
import purr.parse;
import purr.inter;
import purr.srcloc;
import purr.ir.repr;
import purr.ir.walk;

__gshared bool dumpir = false;

string eval(SrcLoc code)
{
    Node node = code.parse;
    Walker walker = new Walker;
    string prog = walker.walkProgram(node);
    return prog;
}

