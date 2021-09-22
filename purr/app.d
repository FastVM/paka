module purr.app;

import purr.ast.walk;
import purr.parse;
import purr.err;
import purr.srcloc;
import purr.ast.ast;
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
import std.process;
import std.datetime.stopwatch;
import core.memory;

extern (C) __gshared string[] rt_options = ["gcopt=gc:manual"];

string outLang = "vm";

alias Thunk = void delegate();

string[] command;

string lang = "paka";

void doBytecode(void[] bc) {
    switch (outLang) {
    case "js":
        char[] src = compile!"js"(bc);
        auto pipes = pipeProcess(command, Redirect.stdin);
        pipes.stdin.write(src);
        pipes.stdin.flush();
        pipes.stdin.close();
        wait(pipes.pid);
        break;
    case "lua":
        char[] src = compile!"lua"(bc);
        auto pipes = pipeProcess(command, Redirect.stdin);
        pipes.stdin.write(src);
        pipes.stdin.flush();
        pipes.stdin.close();
        wait(pipes.pid);
        break;
    case "bc":
        File("out.bc", "wb").rawWrite(bc);
        break;
    case "vm":
        run(bc);
        break;
    default:
        vmError("please select a backend with: --target=help");
        break;
    }
}

Thunk cliCommandHandler(immutable string cmd)
{
    return {
        command = cmd.idup.split;
    };
}

Thunk cliLangHandler(immutable string langName)
{
    return {
        lang = langName.dup;
    };
}

Thunk cliTargetHandler(immutable string lang) {
    return {
        switch (lang)
        {
        case "bc":
            outLang = "bc";
            break;
        case "vm":
            outLang = "vm";
            break;
        case "js":
            outLang = "js";
            command = ["js"];
            break;
        case "node":
            outLang = "js";
            command = ["node"];
            break;
        case "lua":
            outLang = "lua";
            command = ["lua"];
            break;
        case "luajit":
            outLang = "lua";
            command = ["luajit"];
            break;
        case "help":
            vmError("--target=help: try --target=vm or --target=list");
            break;
        case "list":
            vmError("full: vm js node lua luajit");
            break;
        default:
            vmError("invalid --target=" ~ lang);
            break;
        }
    };
}

Thunk cliParseHandler(immutable string code) {
    return { SrcLoc loc = SrcLoc(1, 1, "__main__", code); Node res = loc.parse(lang); };
}

Thunk cliOutHandler(immutable string filename) {
    return {
        SrcLoc code = SrcLoc(1, 1, filename, filename.readText);
        Node node = code.parse(lang);
        Walker walker = new Walker;
        walker.walkProgram(node);
        File outmvm = File("out.bc", "w");
        outmvm.rawWrite(walker.bytecode);
        outmvm.close();
    };
}

Thunk cliConvHandler(immutable string code) {
    return {
        SrcLoc code = SrcLoc(1, 1, "__main__", code);
        Node node = code.parse(lang);
        Walker walker = new Walker;
        walker.walkProgram(node);
        doBytecode(walker.bytecode);
    };
}


Thunk cliConvFileHandler(immutable string filename) {
    return {
        SrcLoc code = SrcLoc(1, 1, filename, filename.readText);
        Node node = code.parse(lang);
        Walker walker = new Walker;
        walker.walkProgram(node);
        doBytecode(walker.bytecode);
    };
}

Thunk cliAstHandler() {
    return { dumpast = !dumpast; };
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
            todo ~= parts[0].cliConvFileHandler;
            break;
        case "--lang":
            todo ~= part1.cliLangHandler;
            break;
        case "--eval":
            todo ~= part1.cliConvHandler;
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
        case "--target":
            todo ~= part1.cliTargetHandler;
            break;
        case "--ast":
            todo ~= cliAstHandler;
            break;
        case "--command":
            todo ~= part1.cliCommandHandler;
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
