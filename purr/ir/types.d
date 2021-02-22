module purr.ir.types;

import std.stdio;
import std.conv;
import std.algorithm;
import std.array;
import purr.dynamic;
import purr.ir.repr;

Type[] checked;
Type[] tostr;

class Type
{
    // static class Any : Type
    // {
    //     override string toString()
    //     {
    //         return "Any";
    //     }
    // }

    static class Nil : Type
    {
        override string toString()
        {
            return "Nil";
        }
    }

    static class Logical : Type
    {
        bool exact;
        double val;

        this()
        {
            exact = false;
        }

        this(bool v)
        {
            exact = true;
            val = v;
        }

        override string toString()
        {
            if (exact)
            {
                return val.to!string;
            }
            else
            {
                return "Logical";
            }
        }
    }

    static class Number : Type
    {
        bool exact;
        double val;

        this()
        {
            exact = false;
        }

        this(double v)
        {
            exact = true;
            val = v;
        }

        override string toString()
        {
            if (exact)
            {
                return val.to!string;
            }
            else
            {
                return "Number";
            }
        }
    }

    static class String : Type
    {
        bool exact;
        string val;

        this()
        {
            exact = false;
        }

        this(string v)
        {
            exact = true;
            val = v;
        }

        override string toString()
        {
            if (exact)
            {
                return '"' ~ val.to!string ~ '"';
            }
            else
            {
                return "String";
            }
        }
    }

    static class Array : Type
    {
        Type.Options[size_t] exact;
        Type.Options elem;

        this(Type.Options e)
        {
            elem = e;
        }

        override string toString()
        {
            foreach (i; tostr)
            {
                if (i is this)
                {
                    return "rec";
                }
            }
            tostr ~= this;
            scope (exit)
            {
                tostr.length--;
            }
            if (exact.length == 0)
            {
                return "Array[" ~ elem.to!string ~ "]";
            }
            else if (elem.options.length == 0)
            {
                size_t[] nums = exact.keys.sort.array;
                string resBody;
                foreach (key, index; nums)
                {
                    if (key != 0)
                    {
                        resBody ~= ", ";
                    }
                    resBody ~= exact[index].to!string;
                }
                return "Tuple[" ~ resBody ~ "]";
            }
            else
            {
                return "Array[*:" ~ elem.to!string ~ ", " ~ exact.to!string[1 .. $ - 1] ~ "]";
            }
        }
    }

    // static class Table : Type
    // {
    //     override string toString()
    //     {
    //         return "Table";
    //     }
    // }

    static class Function : Type
    {
        Type.Options retn;
        Type.Array args;

        this(Type.Options r, Type.Array a)
        {
            retn = r;
            args = a;
        }

        override string toString()
        {
            // return "Function[" ~ args.to!string ~ ", " ~ retn.to!string ~ "]";
            return args.to!string ~ " -> " ~ retn.to!string;
        }
    }

    static class Options : Type
    {
        Type[] options;
        this()
        {
        }

        this(Args...)(Args args)
        {
            static foreach (arg; args)
            {
                options ~= arg;
            }
        }

        this(Type[] opts)
        {
            options = opts;
        }

        Options opBinary(string op : "|")(Type other)
        {
            Options ret = new Options(options.dup);
            ret |= other;
            return ret;
        }

        Options opOpAssign(string op : "|")(Type other)
        {
            if (Options otherOptions = cast(Options) other)
            {
                foreach (opt; otherOptions.options)
                {
                    this |= opt;
                }
                return this;
            }
            else
            {
                foreach (option; options)
                {
                    if (option.supersets(other))
                    {
                        return this;
                    }
                }
                options ~= other;
                return this;
            }
        }

        override string toString()
        {
            foreach (i; tostr)
            {
                if (i is this)
                {
                    return "rec";
                }
            }
            tostr ~= this;
            scope (exit)
            {
                tostr.length--;
            }
            if (options.length == 0)
            {
                return "Unknown";
            }
            if (options.length == 1)
            {
                return options[0].to!string;
            }
            string ret;
            foreach (index, opt; options)
            {
                if (index != 0)
                {
                    ret ~= ", ";
                }
                ret ~= opt.to!string;
            }
            return "Union[" ~ ret ~ "]";
        }

        override bool subsets(Object arg)
        {
            Type type = cast(Type) arg;
            Options other = cast(Options) type;
            if (other is null)
            {
                other = new Options(type);
            }
            foreach (i; checked)
            {
                if (i is this)
                {
                    return true;
                }
            }
            checked ~= this;
            scope (exit)
            {
                checked.length--;
            }
            foreach (t1; options)
            {
                bool okay = false;
                foreach (t2; other.options)
                {
                    if (t1 == t2)
                    {
                        okay = true;
                        break;
                    }
                }
                if (!okay)
                {
                    return false;
                }
            }
            return true;
        }

        Only only(Only)(Only input)
        {
            this |= input;
            foreach (cur; options)
            {
                if (Only ret = cast(Only) cur)
                {
                    return ret;
                }
            }
            assert(false);
        }

        override Type.Options opts()
        {
            return this;
        }
    }

    static Type from(Dynamic val)
    {
        Type ty;
        switch (val.type)
        {
        case Dynamic.Type.nil:
            ty = new Type.Nil;
            break;
        case Dynamic.Type.log:
            ty = new Type.Logical(val.log);
            break;
        case Dynamic.Type.sml:
            ty = new Type.Number(val.as!double);
            break;
        case Dynamic.Type.str:
            ty = new Type.String(val.str);
            break;
        default:
            assert(false);
        }
        return ty;
    }

    bool subsets(Object other)
    {
        return typeid(this) == typeid(other);
    }

    bool supersets(Object other)
    {
        return (cast(Type) other).subsets(this);
    }

    Type.Options opts()
    {
        return new Type.Options(this);
    }
}

class TypeGenerator
{
    Type.Options[] retns = [new Type.Options];
    Type.Array[] argss = [new Type.Array(new Type.Options)];
    Type.Options[][] stacks = [[null]];
    Type.Options[string][] localss;
    string[][] argLocalss;
    string[] argNames;

    ref Type.Options retn()
    {
        return retns[$ - 1];
    }

    ref Type.Array args()
    {
        return argss[$ - 1];
    }

    ref Type.Options[] stack()
    {
        return stacks[$ - 1];
    }

    ref Type.Options[string] locals()
    {
        return localss[$ - 1];
    }

    ref string[] argLocals()
    {
        return argLocalss[$ - 1];
    }

    void pusha()
    {
        retns ~= new Type.Options;
        argss ~= new Type.Array(new Type.Options);
        argLocalss ~= argNames;
        stacks.length++;
        localss.length++;
    }

    void popa()
    {
        retns.length--;
        argss.length--;
        stacks.length--;
        localss.length--;
        argLocalss.length--;
    }

    this()
    {
    }

    ~this()
    {
    }

    Type.Options pop()
    {
        Type.Options popv = stack[$ - 1];
        stack.length--;
        return popv;
    }

    Type.Options[] pops(size_t n)
    {
        Type.Options[] popv = stack[$ - n..$];
        stack.length -= n;
        return popv;
    }

    void start(BasicBlock bb)
    {
        pusha;
    }

    void stop(BasicBlock bb)
    {
        Type.Options ty = new Type.Function(retn, args).opts;
        stacks[$ - 2][$ - 1] = ty;
        popa;
        if (stacks.length == 1)
        {
            writeln("type: ", stack[$-1].options[0]);
        }
    }

    void append(Type.Options ty)
    {
        stack ~= ty;
    }

    void genFrom(Arg)(Arg arg)
    {
        assert(false, Arg.stringof);
    }

    void genFrom(LambdaInstruction lambda)
    {
        stack.length++;
        argNames = lambda.argNames.map!(x => x.str).array;
    }

    void genFrom(PushInstruction push)
    {
        stack ~= Type.from(push.value).opts;
    }

    void genFrom(OperatorInstruction opinst)
    {
        genOp(opinst.op);
    }

    void genFrom(CallInstruction call)
    {
        Type.Options[] args = pops(call.argc);
    }

    void genFrom(ReturnBranch ret)
    {
        retn = retn | pop;
    }

    void genFrom(GotoBranch go)
    {
    }

    void genFrom(LoadInstruction load)
    {
        foreach_reverse (index, scope_; localss)
        {
            foreach (argno, name; argLocalss[index])
            {
                if (name == load.var)
                {
                    stack ~= indexArray(argss[index], new Type.Number(argno));
                    return;
                }
            }
            if (Type.Options* refv = load.var in scope_)
            {
                stack ~= *refv;
                return;
            }
        }
        assert(false, load.var);
    }

    void genFrom(PopInstruction instr)
    {
        pop;
    }

    void genFrom(StoreInstruction store)
    {
        locals[store.var] = stack[$ - 1];
    }

    void genFrom(LogicalBranch branch)
    {
        Type log = pop.only(new Type.Logical);
    }

    void genFrom(ArgsInstruction argsInstr)
    {
        stack ~= args.opts;
    }

    Type.Options indexArray(Type.Array arr, Type.Number num)
    {
        if (num.exact)
        {
            assert(num.val % 1 == 0 && num.val >= 0);
            if (Type.Options* ity = cast(size_t) num.val in arr.exact)
            {
                return *ity;
            }
            else
            {
                Type.Options ity = new Type.Options;
                arr.exact[cast(size_t) num.val] = ity;
                return ity;
            }
        }
        else
        {
            assert(false);
        }
    }

    Type.Options indexArray(Type.Options cls, Type.Options ind)
    {
        Type.Array arr = cls.only(new Type.Array(new Type.Options));
        Type.Number num = ind.only(new Type.Number);
        return indexArray(arr, num);
    }

    void genOp(string op)
    {
        switch (op)
        {
        default:
            assert(false);
        case "index":
            Type.Options ind = pop;
            Type.Options cls = pop;
            stack ~= indexArray(cls, ind);
            break;
        case "cat":
            assert(false);
        case "add":
            Type.Options rhs = pop;
            Type.Options lhs = pop;
            rhs.only(new Type.Number);
            lhs.only(new Type.Number);
            stack ~= new Type.Options(new Type.Number);
            break;
        case "mod":
            Type.Options rhs = pop;
            Type.Options lhs = pop;
            rhs.only(new Type.Number);
            lhs.only(new Type.Number);
            stack ~= new Type.Options(new Type.Number);
            break;
        case "neg":
            assert(false);
        case "sub":
            Type.Options rhs = pop;
            Type.Options lhs = pop;
            rhs.only(new Type.Number);
            lhs.only(new Type.Number);
            stack ~= new Type.Options(new Type.Number);
            break;
        case "mul":
            Type.Options rhs = pop;
            Type.Options lhs = pop;
            rhs.only(new Type.Number);
            lhs.only(new Type.Number);
            stack ~= new Type.Options(new Type.Number);
            break;
        case "div":
            Type.Options rhs = pop;
            Type.Options lhs = pop;
            rhs.only(new Type.Number);
            lhs.only(new Type.Number);
            stack ~= new Type.Options(new Type.Number);
            break;
        case "lt":
            Type.Options rhs = pop;
            Type.Options lhs = pop;
            stack ~= new Type.Options(new Type.Logical);
            break;
        case "gt":
            Type.Options rhs = pop;
            Type.Options lhs = pop;
            stack ~= new Type.Options(new Type.Logical);
            break;
        case "lte":
            Type.Options rhs = pop;
            Type.Options lhs = pop;
            stack ~= new Type.Options(new Type.Logical);
            break;
        case "gte":
            Type.Options rhs = pop;
            Type.Options lhs = pop;
            stack ~= new Type.Options(new Type.Logical);
            break;
        case "neq":
            Type.Options rhs = pop;
            Type.Options lhs = pop;
            stack ~= new Type.Options(new Type.Logical);
            break;
        case "eq":
            Type.Options rhs = pop;
            Type.Options lhs = pop;
            stack ~= new Type.Options(new Type.Logical);
            break;
        }
    }
}
