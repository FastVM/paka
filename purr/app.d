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

State* state;
Node[] nodes;

shared static this() {
    state = vm_state_new();
}

shared static ~this() {
    vm_state_del(state);
}

shared static this() {
    addStyle("paka", [
        "space": Color.init,
        "keyword": Color.light_white,
        "flow": Color.light_magenta,
        "ident": Color.white,
        "number": Color.light_yellow,
        "string": Color.light_cyan,
    ]);
}

string[] last;

string[] pakaColors(string src) {

    Node parsed;

    try {
        parsed = SrcLoc(1, 1, "__color__", src).parse(lang);
    } catch (Problem e) {
        string[] ret2 = last;
        ret2.length = src.length;
        return ret2;
    }

    string[] ret = new string[src.length];

    foreach (index, chr; src) {
        ret[index] = "space";
    }

    void light(Node node) {
        string name = null;
        if (Value val = cast(Value) node) {
            if (val.info == typeid(string)) {
                name = "string";
            }
            if (val.info == typeid(double)) {
                name = "number";
            }
            if (val.info == typeid(int)) {
                name = "number";
            }
            if (val.info == typeid(bool)) {
                name = "keyword";
            }
            if (val.info == typeid(null)) {
                name = "keyword";
            }
        }
        if (Ident id = cast(Ident) node) {
            name = "ident";
        }

        if (name is null) {
            name = "space";
        }

        if (node.fixed && node.file == "__color__") {
            foreach(i; node.offset .. node.offset + node.src.length) {
                ret[i] = name;
            } 
        }

        if (Form form = cast(Form) node) {
            foreach (arg; form.args) {
                light(arg);
            }
        }
    }
    light(parsed);

    // foreach (index, chr; src) {
    //     if ("(){}[]".canFind(chr)) {
    //         ret[index] = "space";
    //     }
    // }

    last = ret;

    return ret;
}

Node convert(Node node) {
    return nodes.replify(node);
    // return node;
} 

void doBytecode(uint[] bc) {
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

Thunk cliReplHandler()
{
    return {
        size_t line = 1;
        bool doExit = false;
        char[][] history;
        Reader reader = new Reader(history);
        reader.style = "paka";
        reader.setColors(src => src.pakaColors);
        scope(exit) {
            history = reader.history;
        }
        while (!stdin.eof) {
            bool setExit = false;
            try {
                string src = reader.readln("(" ~ line.to!string ~ ")> ");
                SrcLoc code = SrcLoc(line, 1, "__repl__", src);
                Node parsed = code.parse(lang);
                Node doMain = convert(parsed);
                Walker walker = new Walker;
                walker.walkProgram(doMain);
                doBytecode(walker.bytecode);
                line += 1;
            } catch (Problem prob) {
                writeln("error: ", prob.msg);
            } catch (ExitException ee) {
                writeln;
                if (ee.letter == 'L') {
                    continue;
                } else if (ee.letter == 'C') {
                    if (doExit) {
                        writeln("Closing REPL"); 
                        break;
                    } else {
                        writeln("Got Ctrl-C, one more to close this REPL"); 
                        setExit = true;
                    }
                } else {
                    writeln("Got Ctrl-" ~ ee.letter ~ ", closing this REPL");
                    break;
                }
            }
            if (setExit) {
                doExit = true;
            } else {
                doExit = false;
            }
        }
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
    Thunk[] todo;
    if (args.length == 0) {
        todo ~= cliReplHandler;
    }
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
        case "--repl":
            todo ~= cliReplHandler;
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
    foreach_reverse (fun; todo) {
        fun();
    }
}

void main(string[] args) {
    domain(args);
}
