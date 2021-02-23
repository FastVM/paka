module purr.ir.types;

import std.stdio;
import std.conv;
import std.algorithm;
import std.array;
import purr.dynamic;
import purr.ir.repr;

Type[] checked;
Type[] tostr;

void collapseNumbers(Type.Options opts)
{
    size_t numc = 0;
    bool isInt = true;
    double min = double.infinity;
    double max = -double.infinity;
    Type[] types;
    foreach (opt; opts.options)
    {
        if (Type.Number num = cast(Type.Number) opt)
        {
            numc++;
            if (num.exact)
            {
                if (num.val % 1 != 0)
                {
                    isInt = false;
                }
                if (num.val < min)
                {
                    min = num.val;
                }
                if (num.val > max)
                {
                    max = num.val;
                }
            }
        }
        else if (Type.Integer integer = cast(Type.Integer) opt)
        {
            numc++;
            if (integer.low < min)
            {
                min = integer.low;
            }
            if (integer.high > max)
            {
                max = integer.high;
            }
        }
        else
        {
            types ~= opt;
        }
    }
    opts.options = types;
    if (numc != 0)
    {
        Type num;
        if (min > max)
        {
            num = new Type.Number;
        }
        if (min == max)
        {
            num = new Type.Number(min);
        } // else if (isInt)
        // {
        //     num = new Type.Integer(min, max);
        // }
    else
        {
            num = new Type.Number;
        }
        if (numc == 1)
        {
            opts.options ~= num;
        }
        else
        {
            opts |= num;
        }
    }
}

void collapseDuplicates(Type.Options opts)
{
    Type[] types;
    outter: foreach (index1, opt1; opts.options)
    {
        foreach (index2, opt2; opts.options)
        {
            if (index1 < index2 && opt1.subsets(opt2))
            {
                continue outter;
            }
        }
        types ~= opt1;
    }
    opts.options = types;
}

void collapse(Type.Options opts)
{
    opts.collapseNumbers;
    opts.collapseDuplicates;
}

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

    static class Integer : Type
    {
        double low;
        double high;

        this(double l, double h)
        {
            low = l;
            high = h;
        }

        override bool subsets(Type other)
        {
            if (typeid(other) != typeid(this))
            {
                return false;
            }
            Integer integer = cast(Integer) other;
            return integer.low <= low && integer.high <= high;
        }

        override string toString()
        {
            return "Integer[" ~ low.to!string ~ ", " ~ high.to!string ~ "]";
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

        override bool subsets(Type other)
        {
            if (typeid(this) != typeid(other))
            {
                return false;
            }
            Number num = cast(Number) other;
            if (this.exact)
            {
                if (num.exact)
                {
                    return val == num.val;
                }
                else
                {
                    return true;
                }
            }
            else
            {
                if (num.exact)
                {
                    return true;
                }
                else
                {
                    return false;
                }
            }
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

        this(Type.Options el = new Type.Options)
        {
            elem = el;
        }

        this(Type.Options[] ex)
        {
            foreach (key, value; ex)
            {
                exact[key] = value;
            }
        }

        this(Type.Options el, Type.Options[] ex)
        {
            elem = el;
            foreach (key, value; ex)
            {
                exact[key] = value;
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
            if (exact.length == 0)
            {
                return "Array[" ~ elem.to!string ~ "]";
            }
            if (elem.options.length == 0)
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
            return "Array[*:" ~ elem.to!string ~ ", " ~ exact.to!string[1 .. $ - 1] ~ "]";
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
            return args.to!string ~ " -> " ~ retn.to!string;
            // return "Function[" ~ args.to!string ~ ", " ~ retn.to!string ~ "]";
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

        bool isAny()
        {
            return options.length == 0;
        }

        Options opBinary(string op : "|")(Type other)
        {
            Options ret = new Options(options.dup);
            ret |= other;
            return ret;
        }

        Options opOpAssign(string op : "|")(Type other)
        {
            assert(this !is null);
            bool replaced = false;
            if (Options otherOptions = cast(Options) other)
            {
                if (!otherOptions.isAny)
                {
                    foreach (opt; otherOptions.options)
                    {
                        this |= opt;
                    }
                    replaced = true;
                }
            }
            foreach (index, option; options)
            {
                if (option.supersets(other))
                {
                    replaced = true;
                    break;
                }
            }
            if (!replaced)
            {
                options ~= other;
                replaced = true;
            }
            collapse(this);
            return this;
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
            if (isAny)
            {
                return "Any";
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

        override bool subsets(Type type)
        {
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
            options ~= input;
            foreach (cur; options)
            {
                if (Only ret = cast(Only) cur)
                {
                    collapse(this);
                    return ret;
                }
            }
            assert(false);
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

    bool subsets(Type other)
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
    Type.Options[] retns = [];
    Type.Array[] argss = [];
    Type.Options[][] stacks = [null];
    Type.Options[string][] localss;
    Type.Function[BasicBlock] blockTypes;
    Type.Options[][BasicBlock] stackAt;
    Type.Options[string][BasicBlock] localsAt;
    void delegate()[BasicBlock] atBlockEntry;
    void delegate()[BasicBlock] atBlockExit;
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
        argLocalss.length++;
        stacks.length++;
        localss.length++;
        foreach (key, argname; argNames)
        {
            argLocals ~= argname;
            args.exact[key] = new Type.Options;
        }
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
        Type.Options[] popv = stack[$ - n .. $];
        stack.length -= n;
        return popv;
    }

    void startFunction(BasicBlock bb, string[] predef)
    {
        stack ~= new Type.Options(new Type.Function(new Type.Options, new Type.Array));
        pusha;
        foreach (sym; predef)
        {
            locals[sym] = new Type.Options;
        }
    }

    void stopFunction(BasicBlock bb)
    {
        Type.Function func = new Type.Function(retn, args);
        Type.Function ty = stacks[$ - 2][$ - 1].only(func);
        ty.retn = retn;
        ty.args = args;
        localsAt[bb] = locals.dup;
        popa;
        // if (stacks.length == 1)
        // {
        //     writeln("type: ", func.retn);
        // }
        blockTypes[bb] = ty; 
    }

    void startBlock(BasicBlock bb)
    {
        stackAt[bb] = stack.dup;
        if (void delegate()* pdel = bb in atBlockEntry)
        {
            (*pdel)();
        }
    }

    void stopBlock(BasicBlock bb)
    {
        if (void delegate()* pdel = bb in atBlockExit)
        {
            (*pdel)();
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
        argNames = lambda.argNames.map!(x => x.str).array;
    }

    void genFrom(PushInstruction push)
    {
        stack ~= new Type.Options(Type.from(push.value));
    }

    void genFrom(OperatorInstruction opinst)
    {
        genOp(opinst.op);
    }

    void genFrom(CallInstruction call)
    {
        Type.Options[] fargs = pops(call.argc);
        Type.Options funcOpts = pop;
        Type.Function defaultTo = new Type.Function(new Type.Options, new Type.Array);
        Type.Function func = funcOpts.only(defaultTo);
        foreach (key, arg; fargs)
        {
            if (Type.Options* opt = key in func.args.exact)
            {
                *opt = arg;
            }
            else
            {
                func.args.exact[key] = arg;
            }
        }
        stack ~= func.retn;
    }

    void genFrom(ReturnBranch ret)
    {
        retn |= pop;
    }

    void genFrom(GotoBranch go)
    {
    }

    void genFrom(LoadInstruction load)
    {
        foreach_reverse (index, scope_; localss)
        {
            if (Type.Options* refv = load.var in scope_)
            {
                stack ~= *refv;
                return;
            }
            foreach (argno, name; argLocalss[index])
            {
                if (name == load.var)
                {
                    stack ~= indexArray(argss[index], new Type.Number(argno));
                    return;
                }
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

    void mergeLogicalBranch()
    {
        Type.Options iffalse = pop;
        Type.Options iftrue = pop;
        stack ~= iffalse | iftrue;
    }

    void genFrom(LogicalBranch branch)
    {
        Type log = pop.only(new Type.Logical);
        if (branch.hasValue)
        {
            void delegate() del = &mergeLogicalBranch;
            atBlockEntry[branch.post] = del;
        }
    }

    void genFrom(ArgsInstruction argsInstr)
    {
        stack ~= new Type.Options(args);
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
            assert(false, "internal bug: array index must be knwon");
        }
    }

    Type.Options indexArray(Type.Options cls, Type.Options ind)
    {
        Type.Array arr = cls.only(new Type.Array(new Type.Options));
        Type.Number num = ind.only(new Type.Number);
        return indexArray(arr, num);
    }

    void mathOp()
    {
        Type.Options rhs = pop;
        Type.Options lhs = pop;
        rhs.only(new Type.Number);
        lhs.only(new Type.Number);
        stack ~= new Type.Options(new Type.Number);
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
            mathOp;
            break;
        case "mod":
            mathOp;
            break;
        case "neg":
            mathOp;
            break;
        case "sub":
            mathOp;
            break;
        case "mul":
            mathOp;
            break;
        case "div":
            mathOp;
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
