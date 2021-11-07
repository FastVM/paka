module purr.app;

import core.time: Duration;
import std.stdio: File, stdin, writeln;
import std.file: readText;
import std.conv: to;
import std.datetime.stopwatch: StopWatch, AutoStart;
import std.array: split, array, join;
import purr.err: Problem, vmError;
import purr.parse: parse;
import purr.srcloc: SrcLoc;
import purr.atext.atext: Reader, Color, ExitException, addStyle;
import purr.ast.ast: Node, Form, Ident, Value;
import purr.ast.repl: replify;
import purr.ast.walk: Walker;
import purr.vm.state: run;
import purr.vm.bytecode: State, vm_state_del, vm_state_new;

version(Fuzz) {} else:

extern (C) __gshared string[] rt_options = ["gcopt=heapSizeFactor:2"];

string outLang = "vm";

alias Thunk = void delegate();

char[][] history;
string[] command;

string lang = "paka";

string astLang = "paka";
File astfile;

Node[] nodes;

State *state;

// shared static this() {
//     addStyle("paka", [
//         "space": Color.init,
//         "keyword": Color.light_white,
//         "flow": Color.light_magenta,
//         "ident": Color.white,
//         "number": Color.light_yellow,
//         "string": Color.light_cyan,
//     ]);
// }

Node convert(Node node) {
    return node;
} 

void doBytecode(int[] bc) {
    final switch (outLang) {
    case "bc":
        File("out.bc", "wb").rawWrite(bc);
        break;
    case "vm":
        run(bc, state);
        break;
    case "none":
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
        Node node = convert(loc.parse(lang));  
    };
}

Thunk cliEvalHandler(immutable string code) {
    return {
        SrcLoc code = SrcLoc(1, 1, "__main__", code);
        Node node = convert(code.parse(lang));
        Walker walker = new Walker;
        walker.walkProgram(node);
        doBytecode(walker.bytecode);
    };
}

Thunk cliFileHandler(immutable string filename) {
    return {
        SrcLoc code = SrcLoc(1, 1, filename, filename.readText);
        Node node = convert(code.parse(lang));
        Walker walker = new Walker;
        walker.walkProgram(node);
        doBytecode(walker.bytecode);
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
    if (args.length == 0) {
        vmError("no cli args given");
    }
    Thunk[] todo;
    size_t end = args.length;
    size_t begin = args.length;
    foreach (index, arg; args) {
        if (arg == "--") {
            end = index ;
            begin = index + 1;
            break;
        }
    }
    foreach_reverse (arg; args[0..end]) {
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
        case "--show":
            todo ~= part1.cliShowHandler;
            break;
        case "--file":
            todo ~= part1.cliFileHandler;
            break;
        case "--lang":
            todo ~= part1.cliLangHandler;
            break;
        case "--eval":
            todo ~= part1.cliEvalHandler;
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
        case "--command":
            todo ~= part1.cliCommandHandler;
            break;
        case "--debug":
            todo ~= cliDebugHandler;
            break;
        }
    }
    const(char)*[] vmargs;
    foreach (arg; args[begin..$]) {
        vmargs ~= (arg ~ "\0").ptr;
    }
    state = vm_state_new(vmargs.length, vmargs.ptr);
    scope(exit)
    {
        vm_state_del(state);
    }
    foreach_reverse (fun; todo) {
        fun();
    }
}

void main(string[] args) {
    domain(args);
}
