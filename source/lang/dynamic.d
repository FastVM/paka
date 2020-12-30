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
import lang.data.rope;
import lang.data.map;

version = safe;

alias Args = Dynamic[];
alias Array = Dynamic[];

alias Mapping = Map!(Dynamic, Dynamic);
Mapping emptyMapping()
{
    return new Mapping;
}

class Table
{
    Mapping table = emptyMapping;
    Table metatable;
    Object native;
    alias table this;

    Table init()
    {
        return Table.empty;
    }

    static Table empty()
    {
        return new Table;
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

    this(typeof(table) t, Object n)
    {
        table = t;
        metatable = null;
        native = n;
    }

    this(typeof(table) t, Table m, Object n)
    {
        table = t;
        metatable = m;
        native = n;
    }

    ref Table meta()
    {
        if (metatable is null)
        {
            metatable = Table.empty;
        }
        return metatable;
    }

    int opApply(int delegate(Dynamic, Dynamic) dg)
    {
        foreach (Dynamic a, Dynamic b; table)
        {
            if (int res = dg(a, b))
            {
                return res;
            }
        }
        return 0;
    }

    Dynamic rawIndex(Dynamic key)
    {
        if (Dynamic* d = key in table)
        {
            return *d;
        }
        throw new BoundsException("key not found: " ~ key.to!string);
    }

    void rawSet(Dynamic key, Dynamic value)
    {
        table[key] = value;
    }

    void set(Dynamic key, Dynamic value)
    {
        Dynamic* metaset = dynamic("set") in meta;
        if (metaset !is null)
        {
            (*metaset)([dynamic(this), key, value]);
        }
        rawSet(key, value);
    }

    Dynamic opIndex(Dynamic key)
    {
        Dynamic* metaget = dynamic("get") in meta;
        if (metaget !is null)
        {
            if (metaget.type == Dynamic.Type.tab)
            {
                Dynamic* val = key in this;
                if (val !is null)
                {
                    return *val;
                }
                return (*metaget).tab[key];
            }
            return (*metaget)([dynamic(this), key]);
        }
        Dynamic* val = key in this;
        if (val !is null)
        {
            return *val;
        }
        throw new TypeException("table item not found: " ~ key.to!string);
    }

    Dynamic* opBinaryRight(string op)(Dynamic other) if (op == "in")
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
        if (op !is null)
        {
            return (*op)([dynamic(this)]).to!string;
        }
        char[] ret;
        ret ~= "{";
        size_t i = 0;
        foreach (key, value; table)
        {
            if (i != 0)
            {
                ret ~= ", ";
            }
            ret ~= key.to!string;
            ret ~= ": ";
            ret ~= value.to!string;
            i++;
        }
        ret ~= "}";
        return cast(string) ret;
    }
}

bool fastMathNotEnabled = false;

pragma(inline, true) Dynamic dynamic(T...)(T a)
{
    return Dynamic(a);
}

struct Dynamic
{
    enum Type : byte
    {
        nil,
        log,
        sml,
        str,
        arr,
        tab,
        fun,
        del,
        pro,
        end,
        pac,
        obj,
    }

    union Value
    {
        bool log;
        double sml;
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
        Object obj;
    }

align(8):
pragma(inline, true):
    Value value = void;
    Type type = Type.nil;

    static Dynamic strToNum(string s)
    {
        return dynamic(s.to!double);
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

    this(double num)
    {
        value.sml = num;
        type = Type.sml;
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

    this(Mapping tab)
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

    this(Object obj)
    {
        value.obj = obj;
        type = Type.obj;
    }

    static Dynamic nil()
    {
        Dynamic ret = dynamic(false);
        ret.value = Dynamic.Value.init;
        ret.type = Dynamic.Type.nil;
        return ret;
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
        return cmpDynamic(this, other);
    }

    int flatOpCmp(Dynamic other)
    {
        Type t = type;
        switch (t)
        {
        default:
            // assert(0);
            throw new TypeException(
                    "error: not comparable: " ~ this.to!string ~ " " ~ other.to!string);
        case Type.nil:
            return 0;
        case Type.log:
            return value.log - other.log;
        case Type.sml:
            double a = value.sml;
            double b = other.value.sml;
            if (a < b)
            {
                return -1;
            }
            if (a == b)
            {
                return 0;
            }
            return 1;
        case Type.str:
            return cmp(*value.str, other.str);
        }
    }

    bool opEquals(const Dynamic other) const
    {
        return cmpDynamic(this, other) == 0;
    }

    Dynamic opBinary(string op)(Dynamic other)
    {
        if (type == Type.sml)
        {
            if (other.type == Type.sml)
            {
                return dynamic(mixin("value.sml " ~ op ~ " other.value.sml"));
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
            if (type == Type.arr && other.type == Type.sml)
            {
                Dynamic[] ret;
                foreach (i; 0 .. other.value.sml)
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
        return dynamic(mixin(op ~ "value.sml"));
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

    Object obj()
    {
        version (safe)
            if (type != Type.obj)
            {
                throw new TypeException("expected native object type");
            }
        return value.obj;
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
                throw new TypeException("expected callable type not " ~ type.to!string);
            }
        return value.fun;
    }

    T as(T)() if (is(T == size_t))
    {
        if (type == Type.sml)
        {
            return cast(size_t) value.sml;
        }
        throw new TypeException("expected numeric type");
    }

    T as(T)() if (is(T == long))
    {
        if (type == Type.sml)
        {
            return cast(long) value.sml;
        }
        else
        {
            throw new TypeException("expected numeric type");
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
            throw new TypeException("expected numeric type");
        }
    }

    bool isTruthy()
    {
        return type != Type.nil && (type != Type.log || value.log);
    }
}

private int cmp(T)(T a, T b) if (!is(T == Function) && !is(T == Dynamic))
{
    if (a == b)
    {
        return 0;
    }
    if (a < b)
    {
        return -1;
    }
    return 1;
}

private int cmpFunction(const Function a, const Function b)
{
    return cmp(cast(void*) a, cast(void*) b);
}

Dynamic[2][] above;
private int cmpDynamic(T...)(T a)
{
    int res = cmpDynamicImpl(a);
    return res;
}

private int cmpDynamicImpl(const Dynamic a, const Dynamic b)
{
    Dynamic[2] cur = [a, b];
    foreach (i, p; above)
    {
        if (cur[0] is p[0] && cur[1] is p[1])
        {
            return 0;
        }
    }
    if (b.type != a.type)
    {
        return cmp(a.type, b.type);
    }
    if (a is b)
    {
        return 0;
    }
    switch (a.type)
    {
    default:
        assert(0);
    case Dynamic.Type.nil:
        return 0;
    case Dynamic.Type.log:
        return cmp(a.value.log, b.value.log);
    case Dynamic.Type.str:
        return cmp(*a.value.str, *b.value.str);
    case Dynamic.Type.sml:
        return cmp(a.value.sml, b.value.sml);
    case Dynamic.Type.arr:
        above ~= cur;
        scope (exit)
        {
            above.length--;
        }
        const Dynamic[] as = *a.value.arr;
        const Dynamic[] bs = *b.value.arr;
        if (int c = cmp(as.length, bs.length))
        {
            return c;
        }
        foreach (i; 0 .. as.length)
        {
            if (int res = cmpDynamic(as[i], bs[i]))
            {
                return res;
            }
        }
        return 0;
    case Dynamic.Type.tab:
        above ~= cur;
        scope (exit)
        {
            above.length--;
        }
        Table at = cast(Table) a.value.tab;
        Table bt = cast(Table) b.value.tab;
        if (int c = cmp(at.table.length, bt.table.length))
        {
            return c;
        }
        foreach (key, value; at)
        {
            Dynamic aValue = value;
            const Dynamic* bValue = key in bt;
            if (bValue is null)
            {
                foreach (key2, value2; bt)
                {
                    if (key2 !in at)
                    {
                        return cmpDynamic(key, key2);
                    }
                }
                assert(0);
            }
            if (int res = cmpDynamic(aValue, *bValue))
            {
                return res;
            }
        }
        return 0;
    case Dynamic.Type.fun:
        return cmp(a.value.fun.fun, b.value.fun.fun);
    case Dynamic.Type.del:
        return cmp(a.value.fun.del, b.value.fun.del);
    case Dynamic.Type.pro:
        return cmpFunction(a.value.fun.pro, b.value.fun.pro);
    }
}

Dynamic[] before = null;
private string strFormat(Dynamic dyn)
{
    foreach (i, v; before)
    {
        if (dyn is v)
        {
            return "&" ~ i.to!string;
        }
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
        if (dyn.value.sml % 1 == 0 && dyn.value.sml > long.min && dyn.value.sml < long.max) {
            return to!string(cast(long) dyn.value.sml);
        }
        return dyn.value.sml.to!string;
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
            ret ~= v.to!string;
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
