module purr.ir.native;

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

class NativeBackend : Generator
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
        println("module purr.exe.main;");
        println("import purr.native.lib;");
        println;
        println("Dynamic purrMain = ", mainb);
        println("void main(string[] args){");
        depth++;
        println("args.argParse;");
        println("purrMain(null).maybeEcho;");
        println("exitNow;");
        depth--;
        println("}");
    }

    override void enterAsFunc(BasicBlock bb)
    {
        if (depth == 0)
        {
            enterProgram;
        }
        println("((Dynamic[] args) {");
        foreach (index, argname; args)
        {
            println("    Dynamic ", argname, "_ = args[", index, "];");
        }
        string[] predef = bb.predef;
        foreach (index, local; predef)
        {
            if (!args.canFind(local))
            {
                println("Dynamic ", local, "_ = void;");
            }
        }
        depth++;
        ssize ~= 0;
        maxssize ~= 0;
        locals ~= predef;
        alllocals ~= locals[$-1];
        enterStr;
    }

    override void enter(BasicBlock bb)
    {
        println(bb.name, ":");
    }

    override void exitAsFunc(BasicBlock bb)
    {
        string res = exitStr;
        println("Dynamic[", maxssize[$ - 1], "] stack = void;");
        print(res);
        depth--;
        ssize.length--;
        alllocals.length -= locals[$-1].length;
        locals.length--;
        maxssize.length--;
        println("}).dynamic;");
        if (depth == 0)
        {
            exitProgram;
        }
    }

    override void emit(LambdaInstruction lambdaInstr)
    {
        allargs ~= lambdaInstr.argNames;
        args = lambdaInstr.argNames;
        println("stack[", ssize[$ - 1], "] = ");
        emitAsFunc(lambdaInstr.entry);
        push(1);
        allargs.length -= lambdaInstr.argNames.length;
    }

    override void emit(LoadInstruction loadInstr)
    {
        if (alllocals.canFind(loadInstr.var) || allargs.canFind(loadInstr.var))
        {
            println("stack[", ssize[$ - 1], "] = ", loadInstr.var, "_;");
        }
        else
        {
            println("stack[", ssize[$ - 1], "] = lib.getVar(\"", loadInstr.var, "\");");
        }
        push(1);
    }

    override void emit(CallInstruction callInstr)
    {
        pop(callInstr.argc);
        println("stack[", ssize[$ - 1] - 1, "] = stack[", ssize[$ - 1] - 1,
                "](stack[", ssize[$ - 1], "..", ssize[$ - 1] + callInstr.argc, "]);");
    }

    override void emit(StoreInstruction storeInstr)
    {
        println(storeInstr.var, "_ = stack[", ssize[$ - 1] - 1, "];");
    }

    override void emit(StorePopInstruction storeInstr)
    {
        println(storeInstr.var, "_ = stack[", ssize[$ - 1] - 1, "];");
        pop(1);
    }

    override void emit(OperatorStoreInstruction opStoreInstr)
    {
        println(opStoreInstr.var, "_ = ", opStoreInstr.op, "Op(",
                opStoreInstr.var, "_, stack[", ssize[$ - 1] - 1, "]);");
    }

    override void emit(OperatorStorePopInstruction opStoreInstr)
    {
        println(opStoreInstr.var, "_ = ", opStoreInstr.op, "Op(",
                opStoreInstr.var, "_, stack[", ssize[$ - 1] - 1, "]);");
        pop(1);
    }

    override void emit(PushInstruction pushInstr)
    {
        string sval;
        switch (pushInstr.value.type)
        {
        case Dynamic.Type.nil:
            sval = "Dynamic.nil";
            break;
        case Dynamic.Type.log:
            sval = pushInstr.value.log.to!string ~ ".dynamic";
            break;
        case Dynamic.Type.str:
            sval = "";
            sval ~= "\"";
            foreach (chr; pushInstr.value.str)
            {
                sval ~= "\\x" ~ chr.to!ubyte.to!string(16);
            }
            sval ~= "\"";
            sval ~= ".dynamic";
            break;
        case Dynamic.Type.sml:
            sval = pushInstr.value.as!double.to!string ~ ".dynamic";
            break;
        default:
            throw new Exception("cannot emit instruction " ~ pushInstr.to!string);
        }
        println("stack[", ssize[$ - 1], "] = ", sval, ";");
        push(1);
    }

    override void emit(ArgsInstruction argsInstr)
    {
        println("stack[", ssize[$ - 1], "] = dynamic(args);");
        push(1);
    }

    override void emit(OperatorInstruction opInstr)
    {
        pop(1);
        println("stack[", ssize[$ - 1] - 1, "] = ", opInstr.op, "Op(stack[",
                ssize[$ - 1] - 1, "], stack[", ssize[$ - 1], "]);");
    }

    override void emit(ReturnBranch retBranch)
    {
        pop(1);
        println("return stack[", ssize[$ - 1], "];");
    }

    override void emit(BooleanBranch boolBranch)
    {
        println("if (stack[", ssize[$ - 1] - 1, "].type != Dynamic.Type.nil && stack[",
                ssize[$ - 1] - 1, "].log == true) {");
        depth++;
        println("goto " ~ boolBranch.target[0].name ~ ";");
        depth--;
        println("} else {");
        depth++;
        println("goto " ~ boolBranch.target[1].name ~ ";");
        depth--;
        println("}");
        pop(1);
        emitBase(boolBranch.target[0]);
        emitBase(boolBranch.target[1]);
    }

    override void emit(GotoBranch gotoBranch)
    {
        println("goto " ~ gotoBranch.target[0].name ~ ";");
        emitBase(gotoBranch.target[0]);
    }

    override void emit(PopInstruction popInstr)
    {
        pop(1);
    }
}
