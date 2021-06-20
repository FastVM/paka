module purr.backend.dlang;

import std.conv;
import std.string;
import purr.io;
import purr.inter;
import purr.ir.opt;
import purr.ir.repr;
import purr.type.repr;

class Compiler
{
    string output;
    int num;
    string[] stack;
    string[string] locals;
    Opt opt;
    string[string] funcs;

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
        output ~= "}extern(C)int main(int argc, char** argv){cast(void)main2();return 0;}";
        return funcs.values.join ~ output;
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
        }
        else
        {
            output ~= "return " ~ pop ~ ";";
        }
    }

    void emit(StoreIndexInstruction store)
    {
        assert(false);
    }

    void emit(LoadInstruction instr)
    {
        if (instr.type.size == 0)
        {
            return;
        }
        push(locals[instr.var]);
    }

    void emit(CallInstruction call)
    {
        Type basety = call.func;
        if (Generic generic = call.func.as!Generic)
        {
            basety = generic.specialize(call.args);
        }
        Func functy = basety.as!Func;
        if (functy is null)
        {
            throw new Exception("cannot call: " ~ call.func.to!string);
        }
        if (functy.impl is null)
        {
            assert(false);
        }
        string src = functy.impl.dup;
        src ~= "(";
        foreach (arg; call.args)
        {
            if (arg.size != 0) {
                src ~= pop;
                src ~= ",";
            }
            else {
                src ~= "null,";
            }
        }
        src ~= ")";
        push(src);
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
        switch (op.op)
        {
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
        scope(exit)
        {
            output = lasto;
            locals = lastl;
            stack = lasts;
        }
        locals = null;
        output = null;
        stack = null;
        output ~= "auto " ~ lambda.impl;
        output ~= "(";
        foreach (name; lambda.args)
        {
            output ~= "T_" ~ name ~ ",";
        }
        output ~= ")";
        output ~= "(";
        foreach (name; lambda.args)
        {
            output ~= "T_" ~ name ~ " ";
            output ~= name;
            output ~= ",";
            locals[name] = name;
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
            // output ~= name ~ "= cast(typeof(" ~ name~ "))(" ~ pop ~ ");";
            output ~= name ~ " = " ~ pop ~ ";";
        }
        else
        {
            output ~= "auto " ~ name ~ "=" ~ pop ~ ";";
            locals[name] = name;
        }
    }

    void emit(PrintInstruction instr)
    {
        if (Higher h = instr.type.as!Higher)
        {
            output ~= "drt.write(`" ~ h.type.to!string ~ "`);";
        }
        else
        {
            output ~= "drt.write(" ~ pop ~ ");";
        }
    }
}
