module lang.dynamic;

import std.algorithm;
import std.conv;
import std.format;
import std.functional;
import std.math;
import std.traits;
import std.typecons;
import std.array;
import std.stdio;
import core.memory;
import lang.bytecode;
import lang.vm;
import lang.error;
import lang.number;
import lang.data.rope;
import lang.data.mpfr;
public import lang.number;

version = safe;

alias Args = Dynamic[];
alias Array = Dynamic[];

class Table
{
    Dynamic[Dynamic] table;
    Table metatable;
    alias table this;

    Table init()
    {
        return Table.empty;
    }

    static Table empty()
    {
        return new Table(null);
    }

    this()
    {
    }

    this(typeof(table) t)
    {
        table = t;
        metatable = null;
    }

    this(typeof(table) t, Table m)
    {
        table = t;
        metatable = m;
    }

    ref Table meta()
    {
        if (metatable is null)
        {
            metatable = Table.empty;
        }
        return metatable;
    }

    int opCmp(Dynamic other)
    {
        return meta[dynamic("cmp")]([dynamic(this), other]).opCmp(dynamicZero);
    }

    Dynamic rawIndex(Dynamic value)
    {
        return table[value];
    }

    void rawSet(Dynamic key, Dynamic value)
    {
        table[key] = value;
    }

    void set(Dynamic key, Dynamic value)
    {
        Dynamic* metaset = dynamic("set") in meta;
        if (metaset !is null) {
            (*metaset)([dynamic(this), key, value]);
        }
        table[key] = value;
    }

    Dynamic opIndex(Dynamic key)
    {
        Dynamic* metaget = dynamic("get") in meta;
        if (metaget !is null)
        {
            if (metaget.type == Dynamic.Type.tab)
            {
                Dynamic* val = key in table;
                if (val !is null)
                {
                    return *val;
                }
                return (*metaget).tab[key];
            }
            return (*metaget)([dynamic(this), key]);
        }
        Dynamic* val = key in table;
        if (val !is null)
        {
            return *val;
        }
        throw new TypeException("table item not found: " ~ key.to!string);
    }

    Dynamic* opBinary(string op)(Dynamic other) if (op == "in")
    {
        return other in table;
    }

    Dynamic opBinary(string op)(Dynamic other)
    {
        enum string opname(string op)()
        {
            switch (op)
            {
            default : assert(0);
            case "+" : return "add";
            case "-" : return "sub";
            case "*" : return "mul";
            case "/" : return "div";
            case "%" : return "mod";
            }
        }
        return meta[dynamic(opname!op)]([dynamic(this), other]);
    }

    Dynamic opCall(Dynamic[] args)
    {
        return meta[dynamic("call")](dynamic(this) ~ args);
    }

    Dynamic opUnary(string op)()
    {
        enum string opname(string op)()
        {
            switch (op)
            {
            default : assert(0);
            case "-" : return "neg";
            }
        }
        return meta[dynamic(opname!op)]([this]);
    }

    override string toString()
    {
        Dynamic* op = dynamic("str") in meta;
        if (op is null)
        {
            return table.to!string;
        }
        return (*op)([dynamic(this)]).to!string;
    }
}

Dynamic dynamicZero;

static this()
{
    dynamicZero = dynamic(0);
}

bool fastMathNotEnabled = false;

Dynamic dynamic(T...)(T a)
{
    return Dynamic(a);
}

struct Dynamic
{
    enum Type : long
    {
        nil,
        log,
        sml,
        big,
        str,
        arr,
        tab,
        fun,
        del,
        pro,
        end,
        pac,
    }

    union Value
    {
        bool log;
        SmallNumber sml;
        BigNumber* bnm;
        string* str;
        Array* arr;
        Table tab;
        union Callable
        {
            Dynamic function(Args) fun;
            Dynamic delegate(Args)* del;
            Function pro;
        }

        Callable fun;
    }

    Type type = Type.nil;
    Value value = void;

    static Dynamic strToNum(string s)
    {
        BigNumber big = BigNumber(s);
        if (big.fits && !fastMathNotEnabled)
        {
            return dynamic(SmallNumber(mpfr_get_d(big, mpfr_rnd_t.MPFR_RNDN)));
        }
        return dynamic(big);
    }

    this(Type t)
    {
        type = t;
    }

    this(bool log)
    {
        value.log = log;
        type = Type.log;
    }

    this(SmallNumber num)
    {
        value.sml = num;
        type = Type.sml;
    }

    this(BigNumber num)
    {
        value.bnm = new BigNumber(num);
        type = Type.big;
    }

    this(string str)
    {
        value.str = [str].ptr;
        type = Type.str;
    }

    this(Array arr)
    {
        value.arr = [arr].ptr;
        type = Type.arr;
    }

    this(Dynamic[Dynamic] tab)
    {
        value.tab = new Table(tab);
        type = Type.tab;
    }

    this(Table tab)
    {
        value.tab = tab;
        type = Type.tab;
    }

    this(Dynamic function(Args) fun)
    {
        value.fun.fun = fun;
        type = Type.fun;
    }

    this(Dynamic delegate(Args) del)
    {
        value.fun.del = [del].ptr;
        type = Type.del;
    }

    this(Function pro)
    {
        value.fun.pro = pro;
        type = Type.pro;
    }

    this(Dynamic other)
    {
        value = other.value;
        type = other.type;
    }

    static Dynamic nil()
    {
        Dynamic ret = dynamic(false);
        ret.value = Dynamic.Value.init;
        ret.type = Dynamic.Type.nil;
        return ret;
    }

    size_t toHash() const nothrow
    {
        switch (type)
        {
        default:
            return hashOf(type) ^ hashOf(value);
        case Type.str:
            return hashOf(*value.str);
        case Type.arr:
            return hashOf(*value.arr);
        case Type.tab:
            return hashOf(value.tab.table);
        }
    }

    string toString()
    {
        return this.strFormat;
    }

    Dynamic opCall(Dynamic[] args)
    {
        switch (type)
        {
        case Dynamic.Type.fun:
            return fun.fun(args);
        case Dynamic.Type.del:
            return (*fun.del)(args);
        case Dynamic.Type.pro:
            if (fun.pro.self.length == 0)
            {
                return run(fun.pro, args);
            }
            else
            {
                return run(fun.pro, fun.pro.self ~ args);
            }
        case Dynamic.Type.tab:
            return value.tab(args);
        default:
            throw new TypeException("error: not a function: " ~ this.to!string);
        }
    }

    int opCmp(Dynamic other)
    {
        Type t = type;
        switch (t)
        {
        default:
            assert(0);
        case Type.nil:
            return 0;
        case Type.log:
            return value.log - other.log;
        case Type.sml:
            if (other.type == Type.big)
            {
                return value.sml.asBig.opCmp(*other.value.bnm);
            }
            SmallNumber a = value.sml;
            SmallNumber b = other.value.sml;
            if (a < b)
            {
                return -1;
            }
            if (a == b)
            {
                return 0;
            }
            return 1;
        case Type.big:
            if (other.type == Type.sml)
            {
                return (*value.bnm).opCmp(other.value.sml.asBig);
            }
            return (*value.bnm).opCmp(*other.value.bnm);
        case Type.str:
            return cmp(*value.str, other.str);
        }
    }

    bool opEquals(const Dynamic other) const
    {
        return isEqual(this, other);
    }

    Dynamic opBinary(string op)(Dynamic other)
    {
        if (type == Type.sml)
        {
            if (other.type == Type.sml)
            {
                SmallNumber res = mixin("value.sml " ~ op ~ " other.value.sml");
                if (res.fits)
                {
                    return dynamic(res);
                }
                else
                {
                    return dynamic(mixin("value.sml.asBig " ~ op ~ " other.value.sml.asBig"));
                }
            }
            else if (other.type == Type.big)
            {
                return dynamic(mixin("value.sml.asBig " ~ op ~ "  *other.value.bnm"));
            }
        }
        else if (type == Type.big)
        {
            if (other.type == Type.sml)
            {
                return dynamic(mixin("*value.bnm " ~ op ~ " other.value.sml.asBig"));
            }
            else if (other.type == Type.big)
            {
                return dynamic(mixin("*value.bnm " ~ op ~ " *other.value.bnm"));
            }
        }
        else if (type == Type.tab)
        {
            return mixin("value.tab " ~ op ~ " other");
        }
        static if (op == "~" || op == "+")
        {
            if (type == Type.str && other.type == Type.str)
            {
                return dynamic(str ~ other.str);
            }
            if (type == Type.arr && other.type == Type.arr)
            {
                return dynamic(arr ~ other.arr);
            }
        }
        static if (op == "*")
        {
            if (type == Type.str && other.type == Type.sml)
            {
                string ret;
                foreach (i; 0 .. other.value.sml)
                {
                    ret ~= str;
                }
                return dynamic(ret);
            }
            if (type == Type.str && other.type == Type.big)
            {
                string ret;
                foreach (i; 0 .. other.as!size_t)
                {
                    ret ~= str;
                }
                return dynamic(ret);
            }
            if (type == Type.arr && other.type == Type.sml)
            {
                Dynamic[] ret;
                foreach (i; 0 .. other.value.sml)
                {
                    ret ~= arr;
                }
                return dynamic(ret);
            }
            if (type == Type.arr && other.type == Type.big)
            {
                Dynamic[] ret;
                foreach (i; 0 .. other.as!size_t)
                {
                    ret ~= arr;
                }
                return dynamic(ret);
            }
        }
        throw new TypeException("invalid types: " ~ type.to!string ~ op ~ other.type.to!string);
    }

    Dynamic opUnary(string op)()
    {
        if (type == Type.sml)
        {
            return dynamic(mixin(op ~ "value.sml"));
        }
        else
        {
            return dynamic(mixin(op ~ "*value.bnm"));
        }
    }

    bool log()
    {
        version (safe)
            if (type != Type.log)
            {
                throw new TypeException("expected logical type");
            }
        return value.log;
    }

    string str()
    {
        version (safe)
            if (type != Type.str)
            {
                throw new TypeException("expected string type");
            }
        return *value.str;
    }

    Array arr()
    {
        version (safe)
            if (type != Type.arr)
            {
                throw new TypeException("expected array type");
            }
        return *value.arr;
    }

    Table tab()
    {
        version (safe)
            if (type != Type.tab)
            {
                throw new TypeException("expected table type");
            }
        return value.tab;
    }

    string* strPtr()
    {
        version (safe)
            if (type != Type.str)
            {
                throw new TypeException("expected string type");
            }
        return value.str;
    }

    Array* arrPtr()
    {
        version (safe)
            if (type != Type.arr)
            {
                throw new TypeException("expected array type");
            }
        return value.arr;
    }

    Value.Callable fun()
    {
        version (safe)
            if (type != Type.fun && type != Type.pro && type != Type.del)
            {
                throw new TypeException("expected callable type");
            }
        return value.fun;
    }

    T as(T)() if (is(T == size_t))
    {
        if (type == Type.sml)
        {
            return cast(size_t) value.sml;
        }
        else
        {
            return mpfr_get_ui(value.bnm.mpfr, mpfr_rnd_t.MPFR_RNDN);
        }
    }

    T as(T)() if (is(T == double))
    {
        if (type == Type.sml)
        {
            return cast(double) value.sml;
        }
        else
        {
            return mpfr_get_d(value.bnm.mpfr, mpfr_rnd_t.MPFR_RNDN);
        }
    }
}

private bool isEqual(const Dynamic a, const Dynamic b)
{
    if (b.type != a.type)
    {
        if (a.type == Dynamic.Type.sml)
        {
            if (b.type == Dynamic.Type.big)
            {
                return a.value.sml.asBig == *b.value.bnm;
            }
        }
        if (a.type == Dynamic.Type.big)
        {
            if (b.type == Dynamic.Type.sml)
            {
                return *a.value.bnm == b.value.sml.asBig;
            }
        }
        return false;
    }
    if (a.value == b.value)
    {
        return true;
    }
    switch (a.type)
    {
    default:
        assert(0);
    case Dynamic.Type.nil:
        return true;
    case Dynamic.Type.log:
        return a.value.log == b.value.log;
    case Dynamic.Type.str:
        return *a.value.str == *b.value.str;
    case Dynamic.Type.sml:
        return a.value.sml == b.value.sml;
    case Dynamic.Type.big:
        return *a.value.bnm == *b.value.bnm;
    case Dynamic.Type.arr:
        return *a.value.arr == *b.value.arr;
    case Dynamic.Type.tab:
        return a.value.tab == b.value.tab;
    case Dynamic.Type.fun:
        return a.value.fun.fun == b.value.fun.fun;
    case Dynamic.Type.del:
        return a.value.fun.del == b.value.fun.del;
    case Dynamic.Type.pro:
        return a.value.fun.pro == b.value.fun.pro;
    }
}

private string strFormat(Dynamic dyn, Dynamic[] before = null)
{
    if (canFind(before, dyn))
    {
        return "...";
    }
    before ~= dyn;
    scope (exit)
    {
        before.length--;
    }
    switch (dyn.type)
    {
    default:
        return "???";
    case Dynamic.Type.nil:
        return "nil";
    case Dynamic.Type.log:
        return dyn.log.to!string;
    case Dynamic.Type.sml:
        return dyn.value.sml.to!string;
    case Dynamic.Type.big:
        return (*dyn.value.bnm).to!string;
    case Dynamic.Type.str:
        if (before.length == 0)
        {
            return dyn.str;
        }
        else
        {
            return '"' ~ dyn.str ~ '"';
        }
    case Dynamic.Type.arr:
        char[] ret;
        ret ~= "[";
        foreach (i, v; dyn.arr)
        {
            if (i != 0)
            {
                ret ~= ", ";
            }
            ret ~= strFormat(v, before);
        }
        ret ~= "]";
        return cast(string) ret;
    case Dynamic.Type.tab:
        return dyn.tab.to!string;
    case Dynamic.Type.fun:
        return "<function>";
    case Dynamic.Type.del:
        return "<function>";
    case Dynamic.Type.pro:
        return dyn.fun.pro.to!string;
    }
}
