module lang.bc.types.types;

import std.conv;
import std.stdio;
import std.algorithm;

Object[] above;
Object[] checked;
Object[] tied;
TypeBox[2][] duplicated;
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
    RuntimeType* rtt;
    TypeBox[] children;
    TypeBox generic()
    {
        return this;
    }

    TypeInfo type()
    {
        return typeid(*rtt);
    }

    TypeBox copy()
    {
        TypeBox ret = new TypeBox;
        ret.rtt = [*rtt].ptr;
        return ret;
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
        ret.rtt = [(*rtt).deepcopy].ptr;
        duplicated.length--;
        return ret;
    }

    T as(T)()
    {
        return cast(T)*rtt;
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
        if (!tied.canFind(this))
        {
            tied ~= this;
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

    // void tie(TypeBox to)
    // {
    //     // *to.rtt = *rtt;
    //     *rtt = *to.rtt;
    //     children ~= to;
    //     to.children ~= this;
    // }

    void unite(TypeBox other)
    {
        if (other.type != type && other.type != typeid(UnionType))
        {
            *rtt = new UnionType([copy, other]);
        }
        if (!tied.canFind(this))
        {
            tied ~= this;
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
        }
        else
        {
            assert(fn(this));
        }
        if (!tied.canFind(this))
        {
            tied ~= this;
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
        if (type == typeid(NullType))
        {
            if (other.type != typeid(NullType))
            {
                *rtt = *other.rtt;
            }
            else
            {
                unite(other);
            }
        }
        else
        {
            unite(other);
        }
        if (!tied.canFind(this))
        {
            tied ~= this;
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
        return *rtt == *otherBox.rtt;
    }

    override string toString()
    {
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

class NullType : EnumType
{
    override string toString()
    {
        return "Void";
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
        if (above.canFind(this))
        {
            return "...";
        }
        above ~= this;
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
        if (above.canFind(this))
        {
            return "...";
        }
        above ~= this;
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
        if (above.canFind(this))
        {
            return "...";
        }
        above ~= this;
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
        if (above.canFind(this))
        {
            return "...";
        }
        above ~= this;
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
        if (above.canFind(this))
        {
            return "...";
        }
        above ~= this;
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
        if (above.canFind(this))
        {
            return "...";
        }
        above ~= this;
        scope (exit)
        {
            above.length--;
        }
        return "Union" ~ optionTypes.to!string;
    }
}
