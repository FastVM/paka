module purr.dynamic;

import std.algorithm;
import std.conv;
import std.array;
import std.traits;
import std.stdio;
import core.memory;
import purr.bytecode;
import purr.vm;
import purr.error;
import purr.data.rope;
import purr.data.map;

version = safe;

alias Args = Dynamic[];
alias Array = Dynamic[];

alias Mapping = Map!(Dynamic, Dynamic);
Mapping emptyMapping()
{
    return new Mapping;
}

Table[] beforeTables;

void*[] lookingFor;
class Table
{
    Mapping table = emptyMapping;
    Table metatable;
    void* native;
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
        table = emptyMapping;
    }

    this(typeof(table) t)
    {
        assert(t !is null);
        table = t;
        metatable = null;
    }

    this(typeof(table) t, Table m)
    {
        assert(t !is null);
        table = t;
        metatable = m;
    }

    this(typeof(table) t, void* n)
    {
        assert(t !is null);
        table = t;
        metatable = null;
        native = n;
    }

    this(typeof(table) t, Table m, void* n)
    {
        table = t;
        metatable = m;
        native = n;
    }

    Table withGet(Table newget)
    {
        if (Dynamic* get = "get".dynamic in table)
        {
            *get.arrPtr ~= newget.dynamic;
        }
        else
        {
            table["get".dynamic] = [newget.dynamic].dynamic;
        }
        return this;
    }

    Table withGet(Args...)(Args args) if (args.length != 1)
    {
        if (args.length == 0)
        {
            return this;
        }
        return withGet(args[0]).withGet(args[1 .. $]);
    }

    Table withProto(Table proto)
    {
        withGet(proto);
        meta.withGet(proto.meta);
        return this;
    }

    Table withProto(Args...)(Args args) if (args.length != 1)
    {
        if (args.length == 0)
        {
            return this;
        }
        return withProto(args[0]).withProto(args[1 .. $]);
    }

    ref Table meta()
    {
        if (metatable is null)
        {
            metatable = Table.empty;
        }
        return metatable;
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

    ref Dynamic opIndex(Dynamic key)
    {
        if (Dynamic* val = key in this)
        {
            return *val;
        }
        throw new BoundsException("key not found: " ~ key.to!string);
    }

    Dynamic* opBinaryRight(string op)(Dynamic other) if (op == "in")
    {
        foreach (i; lookingFor)
        {
            if (i == cast(void*) this)
            {
                return null;
            }
        }
        lookingFor ~= cast(void*) this;
        scope (exit)
        {
            lookingFor.length--;
        }
        Dynamic* ret = other in table;
        if (ret)
        {
            return ret;
        }
        if (meta.length == 0)
        {
            return null;
        }
        Dynamic* metaget = "get".dynamic in meta;
        if (metaget !is null && metaget.type == Dynamic.Type.arr)
        {
            foreach (getter; metaget.arr)
            {
                if (Dynamic* got = other in getter.tab)
                {
                    return got;
                }
            }
            return null;
        }
        if (metaget !is null && metaget.type == Dynamic.Type.tab)
        {
            return other in (*metaget).tab;
        }
        return null;
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
        if (Dynamic* dyn = "self".dynamic in meta)
        {
            return meta[dynamic("call")](dyn.arr ~ args);
        }
        return meta[dynamic("call")](args);
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
        foreach (i, v; beforeTables)
        {
            if (v is this)
            {
                return "&" ~ i.to!string;
            }
        }
        beforeTables ~= this;
        scope (exit)
        {
            beforeTables.length--;
        }
        Dynamic* str = "str".dynamic in meta;
        if (str !is null)
        {
            Dynamic res = (*str)([dynamic(this)]);
            if (res.type != Dynamic.Type.str)
            {
                throw new TypeException("str must return a string");
            }
            return res.str;
        }
        return rawToString;
    }

    string rawToString()
    {
        char[] ret;
        ret ~= "table {";
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
        ptr,
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
        double sml;
        string* str;
        Array* arr;
        Dynamic* ptr;
        Table tab;
        union Callable
        {
            Dynamic function(Args) fun;
            Dynamic delegate(Args)* del;
            Function pro;
        }

        Callable fun;
        void* obj;
    }

align(8):
    Value value = void;
    Type typeImpl = Type.nil;

pragma(inline, true):
    // no boxes at all
    // alias type = typeImpl;

    // full boxes
    // Type type(Type val) @property
    // {
    //     return typeImpl = val;
    // }

    // Type type() @property
    // {
    //     if (typeImpl == Dynamic.Type.ptr)
    //     {
    //         return value.ptr.type;
    //     }
    //     return typeImpl;
    // }
    
    // impropper boxes
    ref Type type() return
    {
        if (typeImpl == Dynamic.Type.ptr)
        {
            return value.ptr.type;
        }
        return typeImpl;
    }

    // alias getType;

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

    this(Dynamic* ptr)
    {
        value.ptr = ptr;
        type = Type.ptr;
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
            double a = as!double;
            double b = other.as!double;
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
        if (typeImpl == Type.sml)
        {
            if (other.typeImpl == Type.sml)
            {
                return dynamic(mixin("value.sml " ~ op ~ " other.value.sml"));
            }
        }
        else if (typeImpl == Type.tab)
        {
            return mixin("tab " ~ op ~ " other");
        }
        static if (op == "~" || op == "+")
        {
            if (typeImpl == Type.str && other.typeImpl == Type.str)
            {
                return dynamic(str ~ other.str);
            }
            if (typeImpl == Type.arr && other.typeImpl == Type.arr)
            {
                return dynamic(arr ~ other.arr);
            }
        }
        static if (op == "*")
        {
            if (typeImpl == Type.str && other.typeImpl == Type.sml)
            {
                string ret;
                foreach (i; 0 .. other.as!size_t)
                {
                    ret ~= str;
                }
                return dynamic(ret);
            }
            if (typeImpl == Type.arr && other.typeImpl == Type.sml)
            {
                Dynamic[] ret;
                foreach (i; 0 .. other.as!size_t)
                {
                    ret ~= arr;
                }
                return dynamic(ret);
            }
        }
        if (typeImpl == Type.ptr)
        {
            if (other.typeImpl == Type.ptr)
            {
                return dynamic(mixin("(*this.value.ptr)" ~ op ~ "(*other.value.ptr)"));
            }
            else
            {
                return dynamic(mixin("(*this.value.ptr)" ~ op ~ "other"));
            }
        }
        else
        {
            if (other.typeImpl == Type.ptr)
            {
                return dynamic(mixin("this" ~ op ~ "(*other.value.ptr)"));
            }
            else
            {
                throw new TypeException(
                        "invalid types: " ~ type.to!string ~ op ~ other.type.to!string);
            }
        }
    }

    Dynamic opUnary(string op)()
    {
        return dynamic(mixin(op ~ "as!double"));
    }

    bool log()
    {
        version (safe)
        {
            if (typeImpl != Type.log)
            {
                if (typeImpl == Dynamic.Type.ptr)
                {
                    return value.ptr.log;
                }
                throw new TypeException("expected logical type");
            }
        }
        else if (typeImpl == Dynamic.Type.ptr)
        {
            return value.ptr.log;
        }
        return value.log;
    }

    string str()
    {
        version (safe)
        {
            if (typeImpl != Type.str)
            {
                if (typeImpl == Dynamic.Type.ptr)
                {
                    return value.ptr.str;
                }
                throw new TypeException("expected string type");
            }
        }
        else if (typeImpl == Dynamic.Type.ptr)
        {
            return value.ptr.log;
        }
        return *value.str;
    }

    Array arr()
    {
        version (safe)
        {
            if (typeImpl != Type.arr)
            {
                if (typeImpl == Dynamic.Type.ptr)
                {
                    return value.ptr.arr;
                }
                throw new TypeException("expected array type");
            }
        }
        else if (typeImpl == Dynamic.Type.ptr)
        {
            return value.ptr.log;
        }
        return *value.arr;
    }

    Table tab()
    {
        version (safe)
        {
            if (typeImpl != Type.tab)
            {
                if (typeImpl == Dynamic.Type.ptr)
                {
                    return value.ptr.tab;
                }
                throw new TypeException("expected table type");
            }
        }
        else if (typeImpl == Dynamic.Type.ptr)
        {
            return value.ptr.log;
        }
        return value.tab;
    }

    string* strPtr()
    {
        version (safe)
        {
            if (typeImpl != Type.str)
            {
                if (typeImpl == Dynamic.Type.ptr)
                {
                    return value.ptr.strPtr;
                }
                throw new TypeException("expected string type");
            }
        }
        else if (typeImpl == Dynamic.Type.ptr)
        {
            return value.ptr.log;
        }
        return value.str;
    }

    Array* arrPtr()
    {
        version (safe)
        {
            if (typeImpl != Type.arr)
            {
                if (typeImpl == Dynamic.Type.ptr)
                {
                    return value.ptr.arrPtr;
                }
                throw new TypeException("expected array type");
            }
        }
        else if (typeImpl == Dynamic.Type.ptr)
        {
            return value.ptr.log;
        }
        return value.arr;
    }

    Dynamic* ptr()
    {
        version (safe)
        {
            if (typeImpl != Type.ptr)
            {
                throw new TypeException("expected pointer type");
            }
        }
        return value.ptr;
    }

    ref Dynamic deref()
    {
        return *ptr;
    }

    Value.Callable fun()
    {
        version (safe)
        {
            if (type != Type.fun && type != Type.pro && type != Type.del)
            {
                if (typeImpl == Dynamic.Type.ptr)
                {
                    return value.ptr.fun;
                }
                throw new TypeException("expected callable type not " ~ type.to!string);
            }
        }
        return value.fun;
    }

    T as(T)() if (isIntegral!T)
    {
        if (typeImpl == Type.sml)
        {
            return cast(T) value.sml;
        }
        if (typeImpl == Type.ptr)
        {
            return value.ptr.as!T;
        }
        else
        {
            throw new TypeException("expected numeric type");
        }
    }

    T as(T)() if (isFloatingPoint!T)
    {
        if (typeImpl == Type.sml)
        {
            return cast(T) value.sml;
        }
        if (typeImpl == Type.ptr)
        {
            return value.ptr.as!T;
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

private int cmpDynamic(T...)(T a)
{
    int res = cmpDynamicImpl(a);
    return res;
}

Table[2][] tableAbove;
int cmpTable(Table at, Table bt)
{
    foreach (i, p; tableAbove)
    {
        if (at is p[0] && bt is p[1])
        {
            return 0;
        }
    }
    tableAbove ~= [at, bt];
    scope (exit)
    {
        tableAbove.length--;
    }
    bool noMeta = at.metatable is null && bt.metatable is null;
    if (Dynamic* mcmp = "cmp".dynamic in at.meta)
    {
        return cast(int)(*mcmp)([at.dynamic, bt.dynamic]).as!double;
    }
    if (int c = cmp(at.table.length, bt.table.length))
    {
        return c;
    }
    foreach (key, value; at)
    {
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
        if (int res = cmpDynamic(value, *bValue))
        {
            return res;
        }
    }
    if (noMeta)
    {
        return 0;
    }
    return cmpTable(at.meta, bt.meta);
}

Dynamic[2][] above;
private int cmpDynamicImpl(Dynamic a, Dynamic b)
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
        if (a.type == Dynamic.Type.tab)
        {
            if (Dynamic* aval = "val".dynamic in a.tab.meta)
            {
                a = *aval;
            }
            if (b.type == Dynamic.Type.tab)
            {
                if (Dynamic* bval = "val".dynamic in b.tab.meta)
                {
                    b = *bval;
                }
            }
        }
        else if (b.type == Dynamic.Type.tab)
        {
            if (Dynamic* bval = "val".dynamic in b.tab.meta)
            {
                b = *bval;
            }
        }
        else
        {
            return cmp(a.type, b.type);
        }
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
        return cmp(a.log, b.log);
    case Dynamic.Type.str:
        return cmp(a.str, b.str);
    case Dynamic.Type.sml:
        return cmp(a.as!double, b.as!double);
    case Dynamic.Type.arr:
        above ~= cur;
        scope (exit)
        {
            above.length--;
        }
        const Dynamic[] as = a.arr;
        const Dynamic[] bs = b.arr;
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
        if (a.type == Dynamic.Type.tab)
        {
            if (Dynamic* aval = "val".dynamic in a.tab.meta)
            {
                a = *aval;
            }
        }
        if (b.type == Dynamic.Type.tab)
        {
            if (Dynamic* bval = "val".dynamic in b.tab.meta)
            {
                b = *bval;
            }
        }
        above ~= cur;
        scope (exit)
        {
            above.length--;
        }
        Table at = cast(Table) a.tab;
        Table bt = cast(Table) b.tab;
        return cmpTable(at, bt);
    case Dynamic.Type.fun:
        return cmp(a.fun.fun, b.fun.fun);
    case Dynamic.Type.del:
        return cmp(a.fun.del, b.fun.del);
    case Dynamic.Type.pro:
        return cmpFunction(a.fun.pro, b.fun.pro);
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
        if (dyn.as!double % 1 == 0
                && dyn.as!double > long.min && dyn.as!double < long.max)
        {
            return to!string(cast(long) dyn.as!double);
        }
        return dyn.as!double
            .to!string;
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
