import lang.vm;
import lang.base;
import lang.walk;
import lang.ast;
import lang.bytecode;
import lang.base;
import lang.dynamic;
import lang.parse;
import lang.inter;
import lang.dext.repl;
import std.file;
import std.path;
import std.stdio;
import std.algorithm;
import std.conv;
import std.string;
import std.getopt;
import core.memory;

size_t ctx;

static this() {
    ctx = enterCtx;
}

static ~this() {
    scope (exit)
    {
        exitCtx;
    }
}

extern(C) ushort clock_res_get(int c, int* r) {
    *r = 1;
    return 0;
}

extern(C) void dext_readln();

string[] strs;

extern(C) extern void dext_js_main();

export:
extern(C) void dext_pushstr() {
    strs.length++;
}

extern(C) void dext_popstr() {
    strs.length--;
}

extern(C) void dext_addchar(int code) {
    strs[$-1] ~= cast(char) code;
}

extern(C) string dext_run(string code) {
    Dynamic retval = ctx.eval(code ~ ";");
    return retval.to!string;
}

extern(C) void dext_emplace() {
    Dynamic retval = ctx.eval(strs[$-1] ~ ";");
    strs[$-1] = retval.to!string;
} 

extern(C) void dext_writestr() {
    writeln(strs[$-1]);
}

void main() {
    strs.length = 0;
    GC.disable;    
    try {
        while (true) {
            dext_pushstr;
            dext_readln;
            dext_emplace;
            dext_writestr;
            dext_popstr;
        }
    }
    catch (Exception e) {
        writeln(e.msg);
    }
}
