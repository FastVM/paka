module purr.app;

import purr.ast.walk;
import purr.parse;
import purr.err;
import purr.srcloc;
import purr.ast.ast;
import purr.vm.bytecode;
import purr.ast.walk;
import purr.plugin.plugins;
import purr.bc.opt;
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

version(Fuzz) {}
else:
extern (C) __gshared string[] rt_options = ["gcopt=gc:manual"];

string outLang = "vm";

alias Thunk = void delegate();

string[] command;

string lang = "paka";

string astLang = "zz";
File astfile;
string[] passes;

void doBytecode(void[] bc) {
    foreach (pass; passes) {
        bc = bc.optimize(pass);
    }
    switch (outLang) {
    case "bc":
        File("out.bc", "wb").rawWrite(bc);
        break;
    case "vm":
        run(bc);
        break;
    case "none":
        break;
    default:
        vmError("please select a backend with: --target=help");
        break;
    }
}

Thunk cliPassHandler(immutable string pass) {
    return {
        passes ~= pass;
    };
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
        case "help":
            vmError("--target=help: try --target=vm or --target=bc");
            break;
        default:
            vmError("invalid --target=" ~ lang);
            break;
        }
    };
}

Thunk cliParseHandler(immutable string code) {
    return {
        SrcLoc loc = SrcLoc(1, 1, "__main__", code);
        Node node = loc.parse(lang);  
        if (dumpast) {astfile.write(astLang.unparse(node));}
    };
}

Thunk cliConvHandler(immutable string code) {
    return {
        SrcLoc code = SrcLoc(1, 1, "__main__", code);
        Node node = code.parse(lang);
        if (dumpast) {astfile.write(astLang.unparse(node));}
        Walker walker = new Walker;
        walker.walkProgram(node);
        doBytecode(walker.bytecode);
    };
}


Thunk cliConvFileHandler(immutable string filename) {
    return {
        SrcLoc code = SrcLoc(1, 1, filename, filename.readText);
        Node node = code.parse(lang);
        if (dumpast) {astfile.write(astLang.unparse(node));}
        Walker walker = new Walker;
        walker.walkProgram(node);
        doBytecode(walker.bytecode);
    };
}

Thunk cliAstHandler(string file) {
    return {
        dumpast = !dumpast;
        if (file.length == 0) {
            astfile = stdout;
        } else {
            astfile = File(file, "w");
        }
        outLang = "none";
    };
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

Thunk cliShowHandler(immutable string name) {
    switch (name)
    {
    default:
        return {
            vmError("cannot --show=" ~ name);
        };
    }
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
        case "--pass":
            todo ~= part1.cliPassHandler;
            break;
        case "--show":
            todo ~= part1.cliShowHandler;
            break;
        case "--file":
            todo ~= part1.cliConvFileHandler;
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
        case "--target":
            todo ~= part1.cliTargetHandler;
            break;
        case "--ast":
            todo ~= part1.cliAstHandler;
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
