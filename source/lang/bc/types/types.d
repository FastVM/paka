module lang.bc.types.types;

import std.conv;
import std.stdio;
import std.algorithm;
import std.array;
import lang.bytecode;

Object[] checked;
TypeBox[2][] duplicated;
void*[] tied;
void*[] above;
void*[] opEqualsCmp;
void*[] typeCmp;

T[] deepcopy(T)(T[] v)
{
    T[] ret;
    foreach (i; v)
    {
        ret ~= i.deepcopy;
    }
    return ret;
}

string deepcopy(string v)
{
    return v.dup;
}

Function deepcopy(Function v)
{
    return v;
}

K[V] deepcopy(K, V)(K[V] a)
{
    K[V] ret;
    foreach (k, v; a)
    {
        ret[k.deepcopy] = v.deepcopy;
    }
    return ret;
}

class TypeBox
{
    private RuntimeType* rtt;
    TypeBox[] children;

    TypeBox generic()
    {
        return this;
    }

    TypeInfo type()
    {
        assert(rtt);
        return typeid(*rtt);
    }

    TypeBox deepcopy()
    {
        foreach (kv; duplicated)
        {
            if (kv[0] == this)
            {
                return kv[1];
            }
        }
        TypeBox ret = new TypeBox;
        duplicated ~= [this, ret];
        assert(rtt);
        ret.rtt = [(*rtt).deepcopy].ptr;
        duplicated.length--;
        return ret;
    }

    ref T as(T)()
    {
        assert(rtt);
        if (!cast(T)*rtt)
        {
            throw new Exception("bad type: " ~ to!string(*rtt) ~ " not " ~ typeid(*rtt).to!string);
        }
        return *cast(T*) rtt;
    }

    bool casts1(T)()
    {
        if (type == typeid(UnionType))
        {
            bool canIt = false;
            foreach (ty; as!UnionType.optionTypes)
            {
                if (ty.same!T)
                {
                    canIt = true;
                    break;
                }
            }
            return canIt;
        }
        else
        {
            return type == typeid(T);
        }
    }

    bool same(TypeBox other)
    {
        if (type == typeid(UnionType))
        {
            if (checked.canFind(this))
            {
                return true;
            }
            checked ~= this;
            scope (exit)
            {
                checked.length--;
            }
            bool canIt = false;
            foreach (ty; as!UnionType.optionTypes)
            {
                if (ty.same(other))
                {
                    canIt = true;
                    break;
                }
            }
            return canIt;
        }
        else
        {
            return type == other.type;
        }
    }

    void set(TypeBox other)
    {
        rtt = other.rtt;
        if (!tied.canFind(cast(void*) this))
        {
            tied ~= cast(void*) this;
            scope (exit)
            {
                tied.length--;
            }
            foreach (ref i; children)
            {
                i.set(other);
            }
        }
    }

    void tie(TypeBox to)
    {
        // *to.rtt = *rtt;
        assert(rtt);
        *rtt = *to.rtt;
        children ~= to;
        to.children ~= this;
    }

    void cleanUnionFlatten()
    {
        if (type == typeid(UnionType))
        {
            if (as!UnionType.optionTypes.length == 0)
            {
                set(.type!UnionType);
            }
            else if (as!UnionType.optionTypes.length == 1)
            {
                set(as!UnionType.optionTypes[0]);
            }
            else
            {
                TypeBox[] boxes = as!UnionType.optionTypes;
                as!UnionType.optionTypes = null;
                foreach (opt; boxes)
                {
                    opt.cleanUnionFlatten;
                    if (opt.type == typeid(UnionType))
                    {
                        foreach (opt2; opt.as!UnionType.optionTypes)
                        {
                            if (!as!UnionType.optionTypes.canFind(opt2))
                            {
                                as!UnionType.optionTypes ~= opt2;
                            }
                        }
                    }
                    else
                    {
                        if (!as!UnionType.optionTypes.canFind(opt))
                        {
                            as!UnionType.optionTypes ~= opt;
                        }
                    }
                }
            }
        }
    }

    void unite(TypeBox other)
    {
        if (other.type != type && other.type != typeid(UnionType))
        {
            assert(rtt);
            *rtt = new UnionType([this, other]);
            cleanUnionFlatten;
        }
        if (type == typeid(UnionType) && other.type == typeid(UnionType))
        {
            foreach (ty; other.as!UnionType.optionTypes)
            {
                if (!as!UnionType.optionTypes.canFind(ty))
                {
                    as!UnionType.optionTypes ~= ty;
                }
            }
            cleanUnionFlatten;
        }
        if (!tied.canFind(cast(void*) this))
        {
            tied ~= cast(void*) this;
            scope (exit)
            {
                tied.length--;
            }
            foreach (ref i; children)
            {
                i.unite(other);
            }
        }
    }

    void filter(bool delegate(TypeBox other) fn)
    {
        if (type == typeid(UnionType))
        {
            UnionType ut = as!UnionType;
            TypeBox[] uttys = ut.optionTypes;
            ut.optionTypes = null;
            foreach (utitem; uttys)
            {
                if (fn(utitem))
                {
                    ut.optionTypes ~= utitem;
                }
            }
            cleanUnionFlatten;
        }
        else
        {
            assert(fn(this));
        }
        if (!tied.canFind(cast(void*) this))
        {
            tied ~= cast(void*) this;
            scope (exit)
            {
                tied.length--;
            }
            foreach (ref i; children)
            {
                i.filter(fn);
            }
        }
    }

    void given(TypeBox other)
    {
        unite(other);
        if (!tied.canFind(cast(void*) this))
        {
            tied ~= cast(void*) this;
            scope (exit)
            {
                tied.length--;
            }
            foreach (ref i; children)
            {
                i.unite(other);
            }
        }
    }

    // TypeBox eval()
    // {
    //     if (ExprType et = cast(ExprType) this)
    //     {
    //         return et.eval;
    //     }
    //     return this;
    // }

    override bool opEquals(Object other)
    {
        if (typeCmp.canFind(cast(void*) this))
        {
            return true;
        }
        typeCmp ~= cast(void*) this;
        scope (exit)
        {
            typeCmp.length--;
        }
        TypeBox otherBox = cast(TypeBox) other;
        assert(rtt);
        assert(otherBox.rtt);
        return *rtt == *otherBox.rtt;
    }

    override string toString()
    {
        assert(rtt);
        return to!string(*rtt);
    }
}

class Box(T) : TypeBox
{
    this(A...)(A a)
    {
        rtt = [cast(RuntimeType) new T(a)].ptr;
    }

    override TypeBox generic()
    {
        return cast(TypeBox) this;
    }
}

TypeBox type(T, A...)(A a)
{
    return new Box!T(a).generic;
}

class RuntimeType
{
    RuntimeType deepcopy()
    {
        assert(0);
    }
}

class ExprType : RuntimeType
{
    // override TypeBox eval()
    // {
    //     assert(0);
    // }
}

class ValueExprType : ExprType
{
    TypeBox value;
    this()
    {
    }

    this(TypeBox v)
    {
        value = v;
    }

    override RuntimeType deepcopy()
    {
        foreach (kv; duplicated)
        {
            if (kv[0] == this)
            {
                return cast(ValueExprType) kv[1];
            }
        }
        ValueExprType ret = new ValueExprType;
        duplicated ~= [this, cast(TypeBox) ret];
        ret.value = value.deepcopy;
        duplicated.length--;
        return ret;
    }

    override bool opEquals(Object other)
    {
        if (typeCmp.canFind(cast(void*) this))
        {
            return true;
        }
        typeCmp ~= cast(void*) this;
        scope (exit)
        {
            typeCmp.length--;
        }
        return typeid(this) == typeid(other) && value == (cast(ValueExprType) other).value;
    }

    // override TypeBox eval()
    // {
    //     return value;
    // }

    override string toString()
    {
        if (above.canFind(cast(void*) this))
        {
            return "...";
        }
        above ~= cast(void*) this;
        scope (exit)
        {
            above.length--;
        }
        return value.to!string;
    }
}

class FailExprType : ExprType
{
    string message;
    this()
    {
    }

    this(string m)
    {
        message = m;
    }

    override RuntimeType deepcopy()
    {
        return this;
    }

    override bool opEquals(Object other)
    {
        return typeid(this) == typeid(other);
    }

    // override TypeBox eval()
    // {
    //     throw new Exception("type assert fail: " ~ message);
    // }

    override string toString()
    {
        return "Fail[\"" ~ message ~ "\"]";
    }
}

class CondExprType : ExprType
{
    ExprType cond;
    ExprType iftrue;
    ExprType iffalse;

    this()
    {
    }

    this(ExprType c, ExprType t, ExprType f)
    {
        cond = c;
        iftrue = t;
        iffalse = f;
    }

    // override TypeBox eval()
    // {
    //     if ((cast(BooleanExprType) cond.eval).isTrue)
    //     {
    //         return iftrue.eval;
    //     }
    //     else
    //     {
    //         return iffalse.eval;
    //     }
    // }

    override RuntimeType deepcopy()
    {
        foreach (kv; duplicated)
        {
            if (kv[0] == this)
            {
                return kv[1];
            }
        }
        CondExprType ret = new CondExprType;
        duplicated ~= [this, cast(TypeBox) ret];
        ret.cond = cast(ExprType) cond.deepcopy;
        ret.iftrue = cast(ExprType) iftrue.deepcopy;
        ret.iffalse = cast(ExprType) iffalse.deepcopy;
        duplicated.length--;
        return ret;
    }

    override bool opEquals(Object other)
    {
        if (typeCmp.canFind(cast(void*) this))
        {
            return true;
        }
        typeCmp ~= cast(void*) this;
        scope (exit)
        {
            typeCmp.length--;
        }
        return typeid(this) == typeid(other) && cond == (cast(CondExprType) other).cond
            && iftrue == (cast(CondExprType) other).iftrue && iffalse == (cast(CondExprType) other);
    }

    override string toString()
    {
        if (above.canFind(cast(void*) this))
        {
            return "...";
        }
        above ~= cast(void*) this;
        scope (exit)
        {
            above.length--;
        }
        return "Cond[" ~ cond.to!string ~ ", " ~ iftrue.to!string ~ ", " ~ iffalse.to!string ~ "]";
    }
}

class BooleanExprType : ExprType
{
    bool isTrue;

    this()
    {
    }

    this(bool i)
    {
        isTrue = i;
    }

    // override TypeBox eval()
    // {
    //     return this;
    // }

    override RuntimeType deepcopy()
    {
        return new BooleanExprType(isTrue);
    }

    override string toString()
    {
        return "Boolean[" ~ isTrue.to!string ~ "]";
    }

    override bool opEquals(Object other)
    {
        return typeid(this) == typeid(other) && this.isTrue == (cast(BooleanExprType) other).isTrue;
    }
}

class MatchExprType : BooleanExprType
{
    ExprType lhs;
    ExprType rhs;

    this()
    {
    }

    this(ExprType l, ExprType r)
    {
        lhs = l;
        rhs = r;
    }

    // override TypeBox eval()
    // {
    //     return new BooleanExprType(lhs.eval == rhs.eval);
    // }

    override RuntimeType deepcopy()
    {
        foreach (kv; duplicated)
        {
            if (kv[0] == this)
            {
                return kv[1];
            }
        }
        AndExprType ret = new AndExprType;
        duplicated ~= [this, cast(TypeBox) ret];
        ret.lhs = cast(ExprType) lhs.deepcopy;
        ret.rhs = cast(ExprType) rhs.deepcopy;
        duplicated.length--;
        return ret;
    }

    override bool opEquals(Object other)
    {
        if (typeCmp.canFind(cast(void*) this))
        {
            return true;
        }
        typeCmp ~= cast(void*) this;
        scope (exit)
        {
            typeCmp.length--;
        }
        return typeid(this) == typeid(other) && lhs == (cast(AndExprType) other)
            .lhs && rhs == (cast(AndExprType) other).rhs;
    }

    override string toString()
    {
        if (above.canFind(cast(void*) this))
        {
            return "...";
        }
        above ~= cast(void*) this;
        scope (exit)
        {
            above.length--;
        }
        return "Match[" ~ lhs.to!string ~ ", " ~ rhs.to!string ~ "]";
    }
}

class AndExprType : BooleanExprType
{
    ExprType lhs;
    ExprType rhs;

    this()
    {
    }

    this(ExprType l, ExprType r)
    {
        lhs = l;
        rhs = r;
    }

    // override TypeBox eval()
    // {
    //     if ((cast(BooleanExprType) lhs.eval).isTrue)
    //     {
    //         if ((cast(BooleanExprType) rhs.eval).isTrue)
    //         {
    //             return new BooleanExprType(true);
    //         }
    //     }
    //     return new BooleanExprType(false);
    // }

    override RuntimeType deepcopy()
    {
        foreach (kv; duplicated)
        {
            if (kv[0] == this)
            {
                return kv[1];
            }
        }
        AndExprType ret = new AndExprType;
        duplicated ~= [this, cast(TypeBox) ret];
        ret.lhs = cast(ExprType) lhs.deepcopy;
        ret.rhs = cast(ExprType) rhs.deepcopy;
        duplicated.length--;
        return ret;
    }

    override bool opEquals(Object other)
    {
        if (typeCmp.canFind(cast(void*) this))
        {
            return true;
        }
        typeCmp ~= cast(void*) this;
        scope (exit)
        {
            typeCmp.length--;
        }
        return typeid(this) == typeid(other) && lhs == (cast(AndExprType) other)
            .lhs && rhs == (cast(AndExprType) other).rhs;
    }

    override string toString()
    {
        if (above.canFind(cast(void*) this))
        {
            return "...";
        }
        above ~= cast(void*) this;
        scope (exit)
        {
            above.length--;
        }
        return "And[" ~ lhs.to!string ~ ", " ~ rhs.to!string ~ "]";
    }
}

class EnumType : RuntimeType
{
    override RuntimeType deepcopy()
    {
        return cast(RuntimeType) this;
    }

    override bool opEquals(Object other)
    {
        return typeid(this) == typeid(other);
    }
}

class NilType : EnumType
{
    override string toString()
    {
        return "Nil";
    }
}

class LogicalType : EnumType
{
    override string toString()
    {
        return "Logical";
    }
}

class NumberType : EnumType
{
    override string toString()
    {
        return "Number";
    }
}

class StringType : EnumType
{
    override string toString()
    {
        return "String";
    }
}

class ArrayType : RuntimeType
{
    TypeBox elementType;
    this()
    {
    }

    this(TypeBox e)
    {
        elementType = e;
    }

    override RuntimeType deepcopy()
    {
        ArrayType ret = new ArrayType;
        ret.elementType = elementType.deepcopy;
        return cast(RuntimeType) ret;
    }

    override bool opEquals(Object other)
    {
        if (opEqualsCmp.canFind(cast(void*) this))
        {
            return true;
        }
        opEqualsCmp ~= cast(void*) this;
        scope (exit)
        {
            opEqualsCmp.length--;
        }
        return typeid(this) == typeid(other) && elementType == (cast(ArrayType) other).elementType;
    }

    override string toString()
    {
        if (above.canFind(cast(void*) this))
        {
            return "...";
        }
        above ~= cast(void*) this;
        scope (exit)
        {
            above.length--;
        }
        return "Array[" ~ elementType.to!string ~ "]";
    }
}

class TupleType : RuntimeType
{
    TypeBox[] elementTypes;

    this()
    {
    }

    this(TypeBox[] e)
    {
        elementTypes = e;
    }

    override RuntimeType deepcopy()
    {
        TupleType ret = new TupleType;
        ret.elementTypes = elementTypes.deepcopy;
        return cast(RuntimeType) ret;
    }

    override bool opEquals(Object other)
    {
        if (opEqualsCmp.canFind(cast(void*) this))
        {
            return true;
        }
        opEqualsCmp ~= cast(void*) this;
        scope (exit)
        {
            opEqualsCmp.length--;
        }
        return typeid(this) == typeid(other) && elementTypes == (cast(TupleType) other)
            .elementTypes;
    }

    override string toString()
    {
        if (above.canFind(cast(void*) this))
        {
            return "...";
        }
        above ~= cast(void*) this;
        scope (exit)
        {
            above.length--;
        }
        return "Tuple" ~ elementTypes.to!string ~ "";
    }
}

class FunctionType : RuntimeType
{
    TypeBox returnType;
    TypeBox argumentsType;
    TypeBox[] capture;

    this()
    {
    }

    this(TypeBox r, TypeBox a)
    {
        returnType = r;
        argumentsType = a;
    }

    override RuntimeType deepcopy()
    {
        FunctionType ret = new FunctionType;
        ret.returnType = returnType.deepcopy;
        ret.argumentsType = argumentsType.deepcopy;
        return cast(RuntimeType) ret;
    }

    override bool opEquals(Object other)
    {
        if (opEqualsCmp.canFind(cast(void*) this))
        {
            return true;
        }
        opEqualsCmp ~= cast(void*) this;
        scope (exit)
        {
            opEqualsCmp.length--;
        }
        return typeid(this) == typeid(other) && returnType == (cast(FunctionType) other)
            .returnType && argumentsType == (cast(FunctionType) other).argumentsType;
    }

    override string toString()
    {
        if (above.canFind(cast(void*) this))
        {
            return "...";
        }
        above ~= cast(void*) this;
        scope (exit)
        {
            above.length--;
        }
        return "Function[" ~ returnType.to!string ~ ", " ~ argumentsType.to!string ~ "]";
    }
}

class MappingType : RuntimeType
{
    TypeBox keyType;
    TypeBox valueType;

    this()
    {
    }

    this(TypeBox k, TypeBox v)
    {
        keyType = k;
        valueType = v;
    }

    override RuntimeType deepcopy()
    {
        MappingType ret = new MappingType;
        ret.keyType = keyType.deepcopy;
        ret.valueType = valueType.deepcopy;
        return cast(RuntimeType) ret;
    }

    override bool opEquals(Object other)
    {
        if (opEqualsCmp.canFind(cast(void*) this))
        {
            return true;
        }
        opEqualsCmp ~= cast(void*) this;
        scope (exit)
        {
            opEqualsCmp.length--;
        }
        return typeid(this) == typeid(other) && keyType == (cast(MappingType) other)
            .keyType && valueType == (cast(MappingType) other).valueType;
    }

    override string toString()
    {
        if (above.canFind(cast(void*) this))
        {
            return "...";
        }
        above ~= cast(void*) this;
        scope (exit)
        {
            above.length--;
        }
        return "Mapping[" ~ keyType.to!string ~ ", " ~ valueType.to!string ~ "]";
    }
}

class ClassType : RuntimeType
{
    TypeBox[string] memberTypes;

    override RuntimeType deepcopy()
    {
        ClassType ret = new ClassType;
        ret.memberTypes = memberTypes.deepcopy;
        return cast(RuntimeType) ret;
    }

    override bool opEquals(Object other)
    {
        if (opEqualsCmp.canFind(cast(void*) this))
        {
            return true;
        }
        opEqualsCmp ~= cast(void*) this;
        scope (exit)
        {
            opEqualsCmp.length--;
        }
        return typeid(this) == typeid(other) && memberTypes == (cast(ClassType) other).memberTypes;
    }

    override string toString()
    {
        if (above.canFind(cast(void*) this))
        {
            return "...";
        }
        above ~= cast(void*) this;
        scope (exit)
        {
            above.length--;
        }
        return "Class" ~ memberTypes.to!string;
    }
}

class UnionType : RuntimeType
{
    TypeBox[] optionTypes;

    this()
    {
    }

    this(TypeBox[] o)
    {
        optionTypes = o;
    }

    override RuntimeType deepcopy()
    {
        UnionType ret = new UnionType;
        ret.optionTypes = optionTypes.deepcopy;
        return cast(RuntimeType) ret;
    }

    override bool opEquals(Object other)
    {
        if (opEqualsCmp.canFind(cast(void*) this))
        {
            return true;
        }
        opEqualsCmp ~= cast(void*) this;
        scope (exit)
        {
            opEqualsCmp.length--;
        }
        return typeid(this) == typeid(other) && optionTypes == (cast(UnionType) other).optionTypes;
    }

    override string toString()
    {
        if (above.canFind(cast(void*) this))
        {
            return "...";
        }
        above ~= cast(void*) this;
        scope (exit)
        {
            above.length--;
        }
        return "Union" ~ optionTypes.to!string;
    }
}
