module purr.app;

import std.stdio;
import purr.ast.walk;
import purr.vm;
import purr.srcloc;
import purr.ast.ast;
import purr.parse;
import purr.inter;
import std.stdio;
import purr.vm.bytecode;
import purr.ast.walk;
import std.uuid;
import std.path;
import std.array;
import std.file;
import std.json;
import std.ascii;
import std.algorithm;
import std.conv;
import std.string;
import std.getopt;
import std.datetime.stopwatch;
import core.memory;
import core.time;
import core.stdc.stdlib;

extern (C) __gshared string[] rt_options = ["gcopt=gc:manual"];

alias Thunk = void delegate();

Thunk cliFileHandler(immutable string filename) {
    return {
        string oldLang = langNameDefault;
        scope (exit) {
            langNameDefault = oldLang;
        }
        if (filename.endsWith(".paka")) {
            langNameDefault = "paka";
        }
        if (filename.endsWith(".pn")) {
            langNameDefault = "passerine";
        }
        SrcLoc code = SrcLoc(1, 1, filename, filename.readText);
        // string cdir = getcwd;
        // scope (exit)
        // {
        //     cdir.chdir;
        // }
        // filename.dirName.chdir;
        eval(code);
    };
}

Thunk cliEvalHandler(immutable string code) {
    return { eval(SrcLoc(1, 1, "__main__", code)); };
}

Thunk cliParseHandler(immutable string code) {
    return { SrcLoc loc = SrcLoc(1, 1, "__main__", code); Node res = loc.parse; };
}

Thunk cliCompileHandler(immutable string code) {
    return {
        SrcLoc loc = SrcLoc(1, 1, "__main__", code);
        Node node = loc.parse;
        Walker walker = new Walker;
        Bytecode func = walker.walkProgram(node);
    };
}

Thunk cliLangHandler(immutable string langname) {
    return { langNameDefault = langname; };
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
    langNameDefault = "paka";
    foreach_reverse (arg; args) {
        string[] parts = arg.split("=").array;
        string part1() {
            assert(parts.length != 0);
            if (parts.length == 1) {
                throw new Exception(parts[0] ~ " takes an argument using " ~ parts[0] ~ "=argument");
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
        case "--file":
            todo ~= part1.cliFileHandler;
            break;
        case "--parse":
            todo ~= part1.cliParseHandler;
            break;
        case "--compile":
            todo ~= part1.cliCompileHandler;
            break;
        case "--eval":
            todo ~= part1.cliEvalHandler;
            break;
        case "--lang":
            todo ~= part1.cliLangHandler;
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

void thrown(Err)(Err e) {
    if (debugging) {
        throw e;
    } else {
        writeln(e.msg);
    }
}

/// the main function that handles runtime errors
void trymain(string[] args) {
    try {
        domain(args);
    } catch (Error e) {
        e.thrown;
    } catch (Exception e) {
        e.thrown;
    }
}

void main(string[] args) {
    trymain(args);
}
