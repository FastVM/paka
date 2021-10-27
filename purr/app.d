module purr.app;

import purr.ast.walk;
import purr.parse;
import purr.err;
import purr.srcloc;
import purr.ast.ast;
import purr.ast.lift;
import purr.ast.walk;
import purr.plugin.plugins;
import purr.vm.bytecode;
import purr.vm.state;
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
extern (C) __gshared string[] rt_options = ["gcopt=heapSizeFactor:2"];

string outLang = "vm";

alias Thunk = void delegate();

string[] command;

string lang = "paka";

string astLang = "zz";
File astfile;

__gshared State* state;

shared static this() {
    state = vm_state_new();
}

shared static ~this() {
    vm_state_del(state);
}

void doBytecode(uint[] bc) {
    final switch (outLang) {
    case "bc":
        File("out.bc", "wb").rawWrite(bc);
        break;
    case "vm":
        GC.collect;
        GC.minimize;
        GC.disable;
        run(bc, state);
        GC.enable;
        break;
    case "none":
        break;
    }
}

Thunk cliReplHandler()
{
    return {
        size_t line = 1;
        Node pre = SrcLoc.init.parse("paka.prelude");
        Node[] vals;
        while (!stdin.eof) {
            try {
                write(">>> ");
                SrcLoc code = SrcLoc(line, 1, "repl", readln);
                Node initNode = code.parse("paka.raw");
                Node[] lastVals = vals;
                Node[] after;
                {
                    Lifter pl = new Lifter;
                    pl.liftProgram(pre);
                    Lifter ll = new Lifter;
                    ll.liftProgram(new Form("do", vals, pre, initNode));
                    foreach(name, get; ll.locals) {
                        if (name == "this" || name == "repl.out" || name in pl.locals) {
                            continue;
                        }
                        after ~= new Form("set", new Form("index", new Ident("this"), new Value(name)), get);
                    }
                    vals = null;
                    foreach (name, get; ll.locals) {
                        if (name == "this" || name == "repl.out" || name in pl.locals) {
                            continue;
                        }
                        vals ~= new Form("var", new Ident(name), new Form("index", new Ident("this"), new Value(name)));
                    }
                }
                Node lambdaBody = new Form("do", lastVals, new Form("var", new Ident("repl.return"), initNode), after, new Ident("repl.return"));
                Node mainLambda = new Form("lambda", new Form("args"), lambdaBody);
                Node setFinal = new Form("var", new Ident("repl.out"), new Form("call", mainLambda));
                Node printAll = new Form("call", new Ident("println"), new Ident("repl.out"));
                Node isFinalNone = new Form("!=", new Ident("repl.out"), new Value(null));
                Node maybePrintAll = new Form("if", isFinalNone, printAll, new Value(null));
                Node doMain = new Form("do", pre, setFinal, maybePrintAll);
                if (dumpast) {astfile.write(astLang.unparse(initNode));}
                Node all = new Form("do", doMain);
                Walker walker = new Walker;
                walker.walkProgram(doMain);
                doBytecode(walker.bytecode);
            } catch (Problem prob) {
                writeln("error: ", prob.msg);
            }
            
            line += 1;
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
        Node node = loc.parse(lang);  
        if (dumpast) {astfile.write(astLang.unparse(node));}
    };
}

Thunk cliEvalHandler(immutable string code) {
    return {
        SrcLoc code = SrcLoc(1, 1, "__main__", code);
        Node node = code.parse(lang);
        if (dumpast) {astfile.write(astLang.unparse(node));}
        Walker walker = new Walker;
        walker.walkProgram(node);
        doBytecode(walker.bytecode);
    };
}

Thunk cliFileHandler(immutable string filename) {
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
