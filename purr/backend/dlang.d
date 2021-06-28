module purr.backend.dlang;

import std.conv;
import std.string;
import purr.io;
import purr.inter;
import purr.ir.opt;
import purr.ir.repr;
import purr.type.repr;

string typeFormat(Type t)
{
    if (t.as!Dynamic)
    {
        return "drt.Value";
    }
    else if (t.as!Integer)
    {
        return "double";
    }
    else if (t.as!Float)
    {
        return "double";
    }
    else if (t.as!Nil)
    {
        return "typeof(null)";
    }
    else if (t.as!Logical)
    {
        return "bool";
    }
    else if (t.as!Text)
    {
        return "string";
    }
    else
    {
        throw new Exception("cannot return " ~ t.to!string);
    }
}

class Compiler
{
    string output;
    int num;
    string[] stack;
    string[string] locals;
    Opt opt;
    string[string] funcs;
    Type retty;

    this()
    {
        opt = new Opt;
    }

    string pop()
    {
        string ret = stack[$ - 1];
        stack.length--;
        return ret;
    }

    void push(string src)
    {
        string name = "tmp_" ~ to!string(num++);
        output ~= "auto " ~ name ~ "=" ~ src ~ ";";
        stack ~= name;
    }

    string compile(BasicBlock block)
    {
        output = null;
        opt.opt(block);
        output ~= "static import drt;auto main2() {";
        emit(block);
        output ~= "}int main(int argc, char** argv){cast(void)main2();return 0;}";
        return "extern(C):" ~ funcs.values.join ~ output;
    }

    string emit(BasicBlock block)
    {
        if (block.place < 0)
        {
            output ~= block.name ~ ":{";
            block.place = 0;
            if (dumpir)
            {
                writeln(block);
            }
            foreach (instr; block.instrs)
            {
                emitInstr(instr);
            }
            emitInstr(block.exit);
            output ~= "}";
        }
        return block.name;
    }

    void emitInstr(Emittable em)
    {
        static foreach (Instr; InstrTypes)
        {
            if (typeid(em) == typeid(Instr))
            {
                assert(typeid(Instr) != typeid(Emittable));
                emit(cast(Instr) em);
                return;
            }
        }
        assert(false, "not emittable " ~ em.to!string);
    }

    void emit(LogicalBranch branch)
    {
        output ~= "{";
        output ~= "if (" ~ pop ~ ")";
        output ~= "{ goto " ~ branch.target[0].name ~ ";}";
        output ~= "else { goto " ~ branch.target[1].name ~ ";}";
        output ~= "}";
        int pl = branch.target[1].place;
        branch.target[1].place = 1;
        output ~= "{";
        emit(branch.target[0]);
        output ~= "}";
        branch.target[1].place = pl;
        output ~= "{";
        emit(branch.target[1]);
        output ~= "}";
    }

    void emit(GotoBranch branch)
    {
        BasicBlock block = branch.target[0];
        if (block.place < 0)
        {
            foreach (instr; block.instrs)
            {
                emitInstr(instr);
            }
            emitInstr(block.exit);
        }
        else
        {
            output ~= "goto " ~ branch.target[0].name ~ ";";
            emit(branch.target[0]);
        }
    }

    void emit(ReturnBranch branch)
    {
        if (branch.type.size == 0)
        {
            output ~= "return null;";
            return;
        }
        string val = pop;
        if (retty.as!Dynamic)
        {
            if (branch.type.as!Dynamic)
            {
                output ~= "return " ~ val ~ ".dup;";
            }
            else
            {
                output ~= "return drt.Value(" ~ val ~ ").dup;";
            }
        }
        else {
            if (branch.type.as!Dynamic)
            {
                output ~= "return "~ val~".as!double;";
            }
            else
            {
                output ~= "return "~ val~";";
            }
        }
    }

    void emit(StoreIndexInstruction store)
    {
        if (store.type.size == 0)
        {
            return;
        }
        string val = pop;
        string ind = pop;
        string var = pop;
        output ~= var ~ "[" ~ ind ~ "]" ~ "= typeof("~ var ~ "[" ~ ind ~ "])(" ~ val ~ ");";
        push(var ~ "[" ~ ind ~ "]");
    }

    void emit(LoadInstruction instr)
    {
        if (instr.type.size == 0)
        {
            return;
        }
        if (instr.type.fits(Type.dynamic) && instr.var == ".globalThis")
        {
            push("drt.GlobalThis.init");
        }
        else
        {
            push(locals[instr.var]);
        }
    }

    void emit(CallInstruction call)
    {
        Type basety = call.func;
        if (Generic generic = call.func.as!Generic)
        {
            basety = generic.specialize(call.args);
        }
        if (Dynamic dyn = basety.as!Dynamic)
        {
            string src;
            src ~= "(";
            foreach_reverse (arg; call.args)
            {
                if (arg.size != 0)
                {
                    src ~= pop;
                }
                else if (Generic g = arg.as!Generic)
                {
                    Type[] largs = new Type[g.args.length];
                    largs[] = Type.dynamic;
                    Type t = g.specialize(largs);
                    Func f = t.as!Func;
                    assert(f);
                    if (f.ret.as!Dynamic)
                    {
                        src ~= "function(";
                        foreach (n; 0..g.args.length)
                        {
                            src ~= "drt.Value _a_" ~ to!string(g.args.length-1-n) ~ ",";
                        }
                        src ~= "){return ";
                        src ~= "" ~ f.impl;
                        src ~= "!(";
                        foreach (n; 0..g.args.length)
                        {
                            src ~= "drt.Value,";
                        }
                        src ~= ")(";
                        foreach_reverse (n; 0..g.args.length)
                        {
                            src ~= "_a_" ~ n.to!string ~ ",";
                        }
                        src ~= ");}";
                    }
                    else
                    {
                        src ~= "function(";
                        foreach (n; 0..g.args.length)
                        {
                            src ~= "drt.Value _a_" ~ to!string(g.args.length-1-n) ~ ",";
                        }
                        src ~= "){return drt.Value(";
                        src ~= "" ~ f.impl;
                        src ~= "!(";
                        foreach (n; 0..g.args.length)
                        {
                            src ~= "drt.Value,";
                        }
                        src ~= ")(";
                        foreach_reverse (n; 0..g.args.length)
                        {
                            src ~= "_a_" ~ to!string(n) ~ ",";
                        }
                        src ~= ")).ptr;}";
                    }

                }
                else if (Func f = arg.as!Func)
                {
                    src ~= "&" ~ f.impl;
                }
                else
                {
                    src ~= "null";
                }
                src ~= ",";
            }
            src ~= ")";
            push(pop ~ src);
            // push("drt.Value.from(" ~ pop ~ ")");
        }
        else if (Func functy = basety.as!Func)
        {
            if (functy.impl is null)
            {
                assert(false);
            }
            string src = functy.impl.dup;
            src ~= "(";
            string[] strs;
            foreach_reverse (arg; call.args)
            {
                if (arg.size != 0)
                {
                    strs ~= pop;
                }
                else
                {
                    strs ~= "null";
                }
            }
            foreach_reverse (arg; strs)
            {
                src ~= arg;
                src ~= ",";
            }
            src ~= ")";
            push(src);
        }
        else
        {
            throw new Exception("cannot call: " ~ call.func.to!string);
        }
    }

    void emit(PushInstruction instr)
    {
        if (instr.res.size == 0)
        {
        }
        else if (instr.res.fits(Type.nil))
        {
        }
        else if (instr.res.fits(Type.integer))
        {
            long ival = *cast(long*) instr.value.ptr;
            push(ival.to!string ~ "L");
        }
        else if (instr.res.fits(Type.float_))
        {
            double ival = *cast(double*) instr.value.ptr;
            push(ival.to!string ~ "f");
        }
        else if (instr.res.fits(Type.text))
        {
            char* sval = *cast(char**) instr.value.ptr;
            char[] src = "`" ~ sval.fromStringz ~ "`";
            push(src.dup);
        }
        else if (Func func = instr.res.as!Func)
        {
            if (func.impl is null)
            {
                assert(false);
            }
            push(func.impl);
        }
        else
        {
            assert(false, instr.res.to!string);
        }
    }

    void emit(OperatorInstruction op)
    {
        string rhs = pop;
        string lhs = pop;
        if (op.op != "index" && op.op != "bind" && op.inputTypes[1].fits(Type.dynamic))
        {
            rhs = rhs ~ ".as!double"; 
        }
        if (op.op != "index" && op.op != "bind" && op.inputTypes[0].fits(Type.dynamic))
        {
            lhs = lhs ~ ".as!double"; 
        }
        switch (op.op)
        {
        case "index":
            push(lhs ~ "[" ~ rhs ~ "]");
            break;
        case "bind":
            push(lhs ~ ".opBind(" ~rhs ~")");
            break;
        case "add":
            push(lhs ~ "+" ~ rhs);
            break;
        case "sub":
            push(lhs ~ "-" ~ rhs);
            break;
        case "mul":
            push(lhs ~ "*" ~ rhs);
            break;
        case "div":
            push(lhs ~ "/" ~ rhs);
            break;
        case "mod":
            push(lhs ~ "%" ~ rhs);
            break;
        case "lt":
            push(lhs ~ "<" ~ rhs);
            break;
        case "gt":
            push(lhs ~ ">" ~ rhs);
            break;
        case "lte":
            push(lhs ~ "<=" ~ rhs);
            break;
        case "gte":
            push(lhs ~ ">=" ~ rhs);
            break;
        case "eq":
            push(lhs ~ "==" ~ rhs);
            break;
        case "neq":
            push(lhs ~ "!=" ~ rhs);
            break;
        default:
            assert(false, op.op);
        }
    }

    void emit(LambdaInstruction lambda)
    {
        string lasto = output;
        string[string] lastl = locals;
        string[] lasts = stack;
        Type lastr = retty;
        scope (exit)
        {
            output = lasto;
            locals = lastl;
            stack = lasts;
            retty = lastr;
        }
        locals = null;
        output = null;
        stack = null;
        retty = lambda.ret;
        output ~= typeFormat(lambda.ret);
        output ~= " ";
        output ~= lambda.impl;
        output ~= "(";
        foreach (name; lambda.args)
        {
            output ~= "_T_" ~ name ~ ",";
        }
        output ~= ")";
        output ~= "(";
        foreach (name; lambda.args)
        {
            output ~= "_T_" ~ name ~ " ";
            output ~= name;
            output ~= ",";
            if (lambda.types[name].as!Dynamic)
            {
                locals[name] = name;
            }
            else
            {
                locals[name] = name;
            }
        }
        output ~= ")";
        output ~= "{";
        emit(lambda.entry);
        output ~= "}";
        funcs[lambda.impl] = output;
    }

    void emit(PopInstruction instr)
    {
        if (instr.type.size == 0)
        {
            return;
        }
        pop;
    }

    void emit(StoreInstruction si)
    {
        if (si.type.size == 0)
        {
            return;
        }
        string name = si.var;
        if (string* pname = name in locals)
        {
            name = *pname;
            output ~= name ~ "= cast(typeof(" ~ name~ "))(" ~ pop ~ ");";
        }
        else
        {
            output ~= "auto " ~ name ~ "=" ~ pop ~ ";";
            locals[name] = name;
        }
    }
}
