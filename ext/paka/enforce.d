module paka.enforce;

import purr.dynamic;
import purr.srcloc;
import std.algorithm;
import std.array;
import std.conv;
string getSrcValue(Span span)
{
    assert(span.first.line == span.last.line);
    string[] strs = span.first.src.splitter("\n").array;
    return strs[span.first.line-1][span.first.column-1 .. span.last.column-1];
}

class Value
{
    Dynamic value;
    this(Dynamic v)
    {
        value = v;
    }

    override string toString()
    {
        return value.to!string;
    }
}

class BaseBinary : Value
{
    Value lhs;
    Value rhs;
    Dynamic result;
    this(Value l, Value r, Dynamic v)
    {
        super(v);
        lhs = l;
        rhs = r;
    }
}

class Binary(string op) : BaseBinary
{
    this(Value l, Value r, Dynamic v)
    {
        super(l, r, v);
    }

    override string toString()
    {
        return lhs.to!string ~ " " ~ op ~ " " ~ rhs.to!string;
    }
}

class Index : BaseBinary
{
    this(Value l, Value r, Dynamic v)
    {
        super(l, r, v);
    }

    override string toString()
    {
        if (rhs.value.type == Dynamic.Type.str)
        {
            return lhs.to!string ~ "." ~ rhs.value.str;
        }
        return lhs.to!string ~ "[" ~ rhs.to!string ~ "]";
    }
}

class Load : Value
{
    string name;
    this(string n, Dynamic v)
    {
        super(v);
        name = n;
    }

    override string toString()
    {
        string valueStr = value.to!string;
        if (valueStr.length > 15)
        {
            return name;
        }
        return valueStr;
    }
}