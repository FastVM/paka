module purr.app;

import purr.ast.walk;
import purr.parse;
import purr.err;
import purr.srcloc;
import purr.ast.ast;
import purr.inter;
import purr.vm.bytecode;
import purr.ast.walk;
import purr.vm;
import std.stdio;
import std.uuid;
import std.path;
import std.array;
import std.file;
import std.algorithm;
import std.conv : to;
import std.string;
import std.getopt;
import std.datetime.stopwatch;
import core.memory;

extern (C) __gshared string[] rt_options = ["gcopt=gc:manual"];

string outLang = "bf";

alias Thunk = void delegate();

Thunk cliFileHandler(immutable string filename) {
    return {
        SrcLoc code = SrcLoc(1, 1, filename, filename.readText); 
        if (filename.endsWith(".scm")) {
            eval(code, "scheme");
        } else {
            eval(code);
        }
    };
}

Thunk cliEvalHandler(immutable string code) {
    return { eval(SrcLoc(1, 1, "__main__", code)); };
}

Thunk cliParseHandler(immutable string code) {
    return { SrcLoc loc = SrcLoc(1, 1, "__main__", code); Node res = loc.parse; };
}

Thunk cliOutHandler(immutable string filename) {
    return {
        SrcLoc code = SrcLoc(1, 1, filename, filename.readText);
        Node node = code.parse;
        Walker walker = new Walker;
        walker.walkProgram(node);
        File outmvm = File("out.bc", "w");
        outmvm.rawWrite(walker.bytecode);
        outmvm.close();
    };
}

Thunk cliLangHandler(immutable string lang) {
    return {
        outLang = lang.dup;
    };
}

Thunk cliConvHandler(immutable string code) {
    return {
        SrcLoc code = SrcLoc(1, 1, "__main__", code);
        Node node = code.parse;
        Walker walker = new Walker;
        walker.walkProgram(node);
        final switch (outLang) {
        case "bf":
            compile!"bf"(walker.bytecode);
            break;
        case "js":
            compile!"js"(walker.bytecode);
            break;
        }
    };
}


Thunk cliConvFileHandler(immutable string filename) {
    return {
        SrcLoc code = SrcLoc(1, 1, filename, filename.readText);
        Node node = code.parse;
        Walker walker = new Walker;
        walker.walkProgram(node);
        final switch (outLang) {
        case "bf":
            compile!"bf"(walker.bytecode);
            break;
        case "js":
            compile!"js"(walker.bytecode);
            break;
        }
    };
}

Thunk cliAstHandler() {
    return { dumpast = !dumpast; };
}

Thunk cliIrHandler() {
    return { dumpir = !dumpir; };
}

Thunk cliTimeHandler(Thunk next) {
    return {
        StopWatch watch = StopWatch(AutoStart.no);
        watch.start();
        next();
        watch.stop();
        writeln(watch.peek);
    };
}

Thunk cliBenchHandler(size_t n, Thunk next) {
    return {
        Duration all;
        foreach (_; 0 .. n) {
            StopWatch watch = StopWatch(AutoStart.no);
            watch.start();
            next();
            watch.stop();
            all += watch.peek;
        }
        writeln("per run: ", all / n);
    };
}

Thunk cliRepeatHandler(size_t n, Thunk next) {
    return {
        foreach (_; 0 .. n) {
            next();
        }
    };
}

bool debugging;

Thunk cliDebugHandler() {
    return { debugging = !debugging; };
}

void domain(string[] args) {
    args = args[1 .. $];
    Thunk[] todo;
    foreach_reverse (arg; args) {
        string[] parts = arg.split("=").array;
        string part1() {
            assert(parts.length != 0);
            if (parts.length == 1) {
                vmError(parts[0] ~ " takes an argument using " ~ parts[0] ~ "=argument");
            }
            return parts[1 .. $].join("=");
        }

        bool runNow = parts[0][$ - 1] == ':';
        scope (exit) {
            if (runNow) {
                Thunk last = todo[$ - 1];
                todo.length--;
                last();
            }
        }
        if (runNow) {
            parts[0].length--;
        }
        switch (parts[0]) {
        default:
            todo ~= parts[0].cliFileHandler;
            break;
        case "--time":
            todo[$ - 1] = todo[$ - 1].cliTimeHandler;
            break;
        case "--repeat":
            todo[$ - 1] = cliRepeatHandler(part1.to!size_t, todo[$ - 1]);
            break;
        case "--bench":
            todo[$ - 1] = cliBenchHandler(part1.to!size_t, todo[$ - 1]);
            break;
        case "--parse":
            todo ~= part1.cliParseHandler;
            break;
        case "--check":
            todo ~= part1.cliOutHandler;
            break;
        case "--eval":
            todo ~= part1.cliEvalHandler;
            break;
        case "--lang-out":
            todo ~= part1.cliLangHandler;
            break;
        case "--compile-expr":
            todo ~= part1.cliConvHandler;
            break;
        case "--compile":
            todo ~= part1.cliConvFileHandler;
            break;
        case "--ast":
            todo ~= cliAstHandler;
            break;
        case "--ir":
            todo ~= cliIrHandler;
            break;
        case "--debug":
            todo ~= cliDebugHandler;
            break;
        }
    }
    foreach_reverse (fun; todo) {
        fun();
    }
}

void main(string[] args) {
    domain(args);
}
