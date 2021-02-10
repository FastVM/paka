module purrc.javascript;

import purr.ir.repr;
import purr.ir.emit;
import purr.dynamic;
import std.stdio;
import std.conv;
import std.algorithm;

string comment(string str)
{
    return "/+" ~ str ~ "+/";
}

class JavascriptBackend : Generator
{
    string[] sval = [""];
    size_t depth = 0;
    size_t[] ssize = [0];
    size_t[] maxssize = [0];
    string[] args;
    string[] allargs;
    string[][] locals;
    string[] alllocals;

    override string repr()
    {
        return sval[$-1];
    }

    void push(size_t n = 0)
    {
        ssize[$ - 1] += n;
        if (ssize[$ - 1] > maxssize[$ - 1])
        {
            maxssize[$ - 1] = ssize[$ - 1];
        }
    }

    void pop(size_t n = 0)
    {
        assert(ssize[$ - 1] >= n);
        ssize[$ - 1] -= n;
    }

    void enterStr(string push = "")
    {
        sval ~= push;
    }

    void exitCatStr()
    {
        print(exitStr);
    }

    string exitStr()
    {
        string ret = sval[$ - 1];
        sval.length--;
        return ret;
    }

    alias emit = Generator.emit;
    alias enter = Generator.enter;
    alias exit = Generator.exit;

    void print(size_t n = 0, Arg)(Arg arg)
    {
        sval[$ - 1 - n] ~= arg.to!string;
    }

    void print(size_t n = 0, Args...)(Args args) if (args.length != 1)
    {
        static foreach (index, arg; args)
        {
            print!n(arg);
        }
    }

    void println(size_t n = 0, Args...)(Args args)
    {
        foreach (index; 0 .. depth)
        {
            print("    ");
        }
        print(args, "\n");
    }

    void enterProgram()
    {
        enterStr;
    }

    void exitProgram()
    {
        string mainb = exitStr;
        println("lib = require('./purrc/libs/javascript.js');");
        println;
        println("var main = ", mainb);
        println("main();");
    }

    override void enter(BasicBlock bb)
    {
        depth--;
        println("case \"", bb.name, "\":");
        depth++;
    }

    override void enterAsFunc(BasicBlock bb)
    {
        if (depth == 0)
        {
            enterProgram;
        }
        println("(function(){");
        depth++;
        string[] predef = bb.predef;
        foreach (index, local; predef)
        {
            if (!args.canFind(local))
            {
                println("var ", local, "_;");
            }
        }
        foreach (index, arg; args)
        {
            println("var ", arg, "_ = arguments[", index, "];");
        }
        println("var place;");
        println("while (true) {");
        depth++;
        println("switch(place) {");
        depth++;
        println("default:");
        depth++;
        ssize ~= 0;
        maxssize ~= 0;
        locals ~= predef;
        alllocals ~= locals[$-1];
        enterStr;
    }

    override void exitAsFunc(BasicBlock bb)
    {
        string res = exitStr;
        print(res);
        ssize.length--;
        alllocals.length -= locals[$-1].length;
        locals.length--;
        maxssize.length--;
        depth--;
        depth--;
        println("}");
        depth--;
        println("}");
        depth--;
        println("})");
        if (depth == 0)
        {
            exitProgram;
        }
    }

    override void emit(LambdaInstruction lambdaInstr)
    {
        allargs ~= lambdaInstr.argNames;
        string[] oargs = args;
        args = lambdaInstr.argNames;
        println("var stack", ssize[$ - 1], " = ");
        depth++;
        emitAsFunc(lambdaInstr.entry);
        depth--;
        push(1);
        args = oargs;
        allargs.length -= lambdaInstr.argNames.length;
    }

    override void emit(LoadInstruction loadInstr)
    {
        if (alllocals.canFind(loadInstr.var) || allargs.canFind(loadInstr.var))
        {
            println("var stack", ssize[$ - 1], " = ", loadInstr.var, "_;");
        }
        else
        {
            println("var stack", ssize[$ - 1], " = lib(\"", loadInstr.var, "\");");
        }
        push(1);
    }

    override void emit(CallInstruction callInstr)
    {
        pop(callInstr.argc);
        string names;
        foreach (index; ssize[$ - 1] .. ssize[$ - 1] + callInstr.argc)
        {
            if (index != ssize[$ - 1])
            {
                names ~= ", ";
            }
            names ~= "stack" ~ index.to!string;
        }
        println("var stack", ssize[$ - 1] - 1, " = stack", ssize[$ - 1] - 1,
                "(" ~ names ~ ");");
    }

    override void emit(StoreInstruction storeInstr)
    {
        println(storeInstr.var, "_ = stack", ssize[$ - 1] - 1, ";");
    }

    // override void emit(StorePopInstruction storeInstr)
    // {
    // }

    // override void emit(OperatorStoreInstruction opStoreInstr)
    // {
    // }

    // override void emit(OperatorStorePopInstruction opStoreInstr)
    // {
    // }

    override void emit(PushInstruction pushInstr)
    {
        string sval;
        switch (pushInstr.value.type)
        {
        case Dynamic.Type.nil:
            sval = "undefined";
            break;
        case Dynamic.Type.log:
            sval = pushInstr.value.log ? "true" : "false";
            break;
        case Dynamic.Type.str:
            sval = "";
            sval ~= "\"";
            foreach (chr; pushInstr.value.str)
            {
                sval ~= "\\x" ~ chr.to!ubyte.to!string(16);
            }
            sval ~= "\"";
            break;
        case Dynamic.Type.sml:
            sval = pushInstr.value.as!double.to!string;
            break;
        default:
            throw new Exception("cannot emit instruction " ~ pushInstr.to!string);
        }
        println("var stack", ssize[$ - 1], " = ", sval, ";");
        push(1);
    }

    // override void emit(ArgsInstruction argsInstr)
    // {
    // }

    override void emit(OperatorInstruction opInstr)
    {
        pop(1);
        println("var stack", ssize[$ - 1] - 1, " = lib.", opInstr.op, "Op(stack",
                ssize[$ - 1] - 1, ", stack", ssize[$ - 1], ");");
    }

    override void emit(ReturnBranch retBranch)
    {
        pop(1);
        println("return stack", ssize[$ - 1], ";");
    }

    override void emit(BooleanBranch boolBranch)
    {
        println("if (stack", ssize[$ - 1] - 1, ") {");
        depth++;
        println("loc = \"" ~ boolBranch.target[0].name ~ "\";");
        println("continue;");
        depth--;
        println("} else {");
        depth++;
        println("loc = \"" ~ boolBranch.target[1].name ~ "\";");
        println("continue;");
        depth--;
        println("}");
        pop(1);
        emitBase(boolBranch.target[0]);
        emitBase(boolBranch.target[1]);
    }

    override void emit(GotoBranch gotoBranch)
    {
        println("loc = " ~ gotoBranch.target[0].name ~ ";");
        println("continue;");
        emitBase(gotoBranch.target[0]);
    }

    override void emit(PopInstruction popInstr)
    {
        pop(1);
    }
}
