module purr.ir.types;

import std.stdio;
import std.conv;
import std.algorithm;
import std.array;
import purr.dynamic;
import purr.ir.repr;
import purr.base;

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
            assert(typeid(opt) != typeid(Type.Options));
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
        }
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
            if (index1 < index2)
            {
                if (opt1.subsets(opt2))
                {
                    continue outter;
                }
            }
        }
        types ~= opt1;
    }
    opts.options = types;
}

void collapse(Type.Options opts)
{
    opts.collapseDuplicates;
    opts.collapseNumbers;
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
                    return true;
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

    static class Table : Type
    {
        Type.Options[string] exact;
        Type.Options[2] elem;

        this(Type.Options[2] el = [new Type.Options, new Type.Options])
        {
            elem = el;
        }

        this(Type.Options[string] ex)
        {
            foreach (key, value; ex)
            {
                exact[key] = value;
            }
        }

        this(Type.Options[2] el, Type.Options[string] ex)
        {
            elem = el;
            foreach (key, value; ex)
            {
                exact[key] = value;
            }
        }

        ref Type.Options key()
        {
            return elem[0];
        }

        ref Type.Options value()
        {
            return elem[1];
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
                return "Table[key:" ~ key.to!string ~ ", value:" ~ value.to!string ~ "]";
            }
            if (elem[0].options.length == 0 && elem[1].options.length == 0)
            {
                string resBody;
                size_t count;
                foreach (key, value; exact)
                {
                    if (count != 0)
                    {
                        resBody ~= ", ";
                    }
                    resBody ~= key.to!string ~ ":" ~ value.to!string;
                    count++;
                }
                return "Struct[" ~ resBody ~ "]";
            }
            return "Table[key:" ~ key.to!string ~ ", value:" ~ value.to!string ~ "]";
        }
    }

    static class Function : Type
    {
        Type.Options retn;
        Type.Array args;
        bool exact;
        string func;

        this(Type.Options r, Type.Array a)
        {
            exact = false;
            retn = r;
            args = a;
        }

        this(Type.Options r, Type.Array a, string f)
        {
            exact = true;
            func = f;
            retn = r;
            args = a;
        }

        override string toString()
        {
            if (exact)
            {
                return "(" ~ func ~ " :: " ~ args.to!string ~ " -> " ~ retn.to!string ~ ")";
            }
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
                this |= arg;
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
            if (Options otherOptions = cast(Options) other)
            {
                foreach (opt; otherOptions.options)
                {
                    this |= opt;
                }
                collapse(this);
                return this;
            }
            foreach (index, option; options)
            {
                if (other.subsets(option))
                {
                    collapse(this);
                    return this;
                }
            }
            options ~= other;
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
            this |= input;
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
    Type.Options[][] stacks = [null];
    Type.Options[string][] localss = [null];
    Type.Options[string][] capturess = [null];
    string[][] argLocalss = [null];
    Type.Array[] argss = [null];
    Type.Function[BasicBlock] blockTypes;
    Type.Options[][BasicBlock] stackAt;
    Type.Options[] retns;
    Type.Options[string][BasicBlock] localsAt;
    Type.Options[string][BasicBlock] capturesAt;
    void delegate()[BasicBlock] atBlockEntry;
    void delegate()[BasicBlock] atBlockExit;
    string[] argNames;
    Type.Options[][2] stackDatas;

    this()
    {
        locals = loadBaseTypes;
    }

    ~this()
    {
    }

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

    ref Type.Options[string] captures()
    {
        return capturess[$ - 1];
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
        capturess.length++;
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
        capturess.length--;
        localss.length--;
        argLocalss.length--;
    }

    Type.Options pop()
    {
        stackDatas[0] ~= stack[$ - 1];
        Type.Options popv = stack[$ - 1];
        stack.length--;
        return popv;
    }

    Type.Options[] pops(size_t n)
    {
        Type.Options[] popv = stack[$ - n .. $];
        foreach (i; 0 .. n)
        {
            pop;
        }
        return popv;
    }

    void push(Type.Options value)
    {
        stack ~= value;
        stackDatas[1] ~= stack[$ - 1];
    }

    void startFunction(BasicBlock bb, string[] predef)
    {
        push = new Type.Options(new Type.Function(new Type.Options, new Type.Array));
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
        capturesAt[bb] = captures.dup;
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
        push = ty;
    }

    void genFrom(Arg)(Arg arg)
    {
        stackDatas = [null, null];
        Type.Options[] stc = stack.dup;
        genFromInstr(arg);
        arg.stackData = [stackDatas[0], stackDatas[1]];
    }

    void genFromInstr(Arg)(Arg arg)
    {
        assert(false, Arg.stringof);
    }

    void genFromInstr(LambdaInstruction lambda)
    {
        argNames = lambda.argNames.map!(x => x.str).array;
    }

    void genFromInstr(PushInstruction ipush)
    {
        push = new Type.Options(Type.from(ipush.value));
    }

    void genFromInstr(OperatorStoreInstruction opstore)
    {
        pushLocal(opstore.var);
        genOp(opstore.op);
        Type.Options opts = pop;
        locals[opstore.var] = opts;
        push = opts;
    }

    void genFromInstr(OperatorInstruction opinst)
    {
        genOp(opinst.op);
    }

    void genFromInstr(CallInstruction call)
    {
        Type.Options[] fargs = pops(call.argc);
        Type.Options funcOpts = pop;
        Type.Function func;
        foreach_reverse (opt; funcOpts.options)
        {
            if (typeid(opt) == typeid(Type.Function))
            {
                func = cast(Type.Function) opt;
                break;
            }
        }
        if (func is null)
        {
            Type.Function defaultTo = new Type.Function(new Type.Options, new Type.Array);
            func = funcOpts.only(defaultTo);
        }
        if (func.exact)
        {
            func = new Type.Function(func.retn, new Type.Array, func.func);
            funcOpts.options ~= func;
        }
        // if (!func.exact)
        // {
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
        // }
        // writeln(func.retn, " <- ", func.args);
        push = func.retn;
    }

    void genFromInstr(ReturnBranch ret)
    {
        Type.Options res = pop;
        retn |= res;
        push = res;
    }

    void genFromInstr(GotoBranch go)
    {
    }

    void pushLocal(string var)
    {
        int count = 0;
        foreach_reverse (index, scope_; localss)
        {
            if (Type.Options* refv = var in scope_)
            {
                push = *refv;
                foreach (ref capt; capturess[$ - count .. $])
                {
                    capt[var] = stack[$ - 1];
                }
                return;
            }
            foreach (argno, name; argLocalss[index])
            {
                if (name == var)
                {
                    push = indexArray(argss[index], new Type.Number(argno));
                    foreach (ref capt; capturess[$ - count .. $])
                    {
                        capt[var] = stack[$ - 1];
                    }
                    return;
                }
            }
            count++;
        }
        assert(false, "variable not found " ~ var);
    }

    void genFromInstr(LoadInstruction load)
    {
        pushLocal(load.var);
    }

    void genFromInstr(PopInstruction instr)
    {
        pop;
    }

    void genFromInstr(StoreInstruction store)
    {
        Type.Options opts = pop;
        locals[store.var] = opts;
        push = opts;
    }

    void mergeLogicalBranch()
    {
        Type.Options iffalse = pop;
        Type.Options iftrue = pop;
        push = iffalse | iftrue;
    }

    void genFromInstr(LogicalBranch branch)
    {
        Type log = pop.only(new Type.Logical);
        if (branch.hasValue)
        {
            void delegate() del = &mergeLogicalBranch;
            atBlockEntry[branch.post] = del;
        }
    }

    void genFromInstr(ArgsInstruction argsInstr)
    {
        push = new Type.Options(args);
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
            return null;
        }
    }

    Type.Options indexTable(Type.Table tab, Type.String str)
    {
        if (str.exact)
        {
            if (Type.Options* ity = str.val in tab.exact)
            {
                return *ity;
            }
            else
            {
                Type.Options ity = new Type.Options;
                tab.exact[str.val] = ity;
                return ity;
            }
        }
        else
        {
            return null;
        }
    }

    Type.Options indexArray(Type.Options cls, Type.Options ind)
    {
        Type[] clss = cls.options.dup;
        Type[] inds = ind.options.dup;
        Type.Array arr = cls.only(new Type.Array);
        Type.Number num = ind.only(new Type.Number);
        if (Type.Options ret = indexArray(arr, num))
        {
            return ret;
        }
        cls.options = clss;
        ind.options = inds;
        Type.Table tab = cls.only(new Type.Table);
        Type.String str = ind.only(new Type.String);
        if (Type.Options ret = indexTable(tab, str))
        {
            return ret;
        }
        throw new Exception("not indexable: " ~ cls.to!string);
    }

    void mathOp()
    {
        Type.Options rhs = pop;
        Type.Options lhs = pop;
        rhs.only(new Type.Number);
        lhs.only(new Type.Number);
        push = new Type.Options(new Type.Number);
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
            push = indexArray(cls, ind);
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
            push = new Type.Options(new Type.Logical);
            break;
        case "gt":
            Type.Options rhs = pop;
            Type.Options lhs = pop;
            push = new Type.Options(new Type.Logical);
            break;
        case "lte":
            Type.Options rhs = pop;
            Type.Options lhs = pop;
            push = new Type.Options(new Type.Logical);
            break;
        case "gte":
            Type.Options rhs = pop;
            Type.Options lhs = pop;
            push = new Type.Options(new Type.Logical);
            break;
        case "neq":
            Type.Options rhs = pop;
            Type.Options lhs = pop;
            push = new Type.Options(new Type.Logical);
            break;
        case "eq":
            Type.Options rhs = pop;
            Type.Options lhs = pop;
            push = new Type.Options(new Type.Logical);
            break;
        }
    }
}
