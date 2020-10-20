module lang.data.map;

import core.memory;
import std.algorithm;
import std.stdio;

int compare(T1, T2)(T1 a, T2 b)
{
    static if (__traits(compiles, cmp(a, b)))
    {
        return cmp(a, b);
    }
    else static if (__traits(compiles, a.opCmp(b)))
    {
        return a.opCmp(b);
    }
    else
    {
        return a < b ? -1 : a == b ? 0 : 1;
    }
}

// struct Map(Key, Value)
// {
//     MapData!(Key, Value) data; // = new MapData!(Key, Value);

//     @disable this();

//     this(MapData!(Key, Value) d)
//     {
//         data = d;
//     }

//     static This empty() {
//         return new 
//     }

//     size_t length() const
//     {
//         return data.length;
//     }

//     int opApply(int delegate(Value) dg)
//     {
//         return data.opApply(dg);
//     }

//     int opApply(int delegate(Key, Value) dg)
//     {
//         return data.opApply(dg);
//     }

//     Value opIndex(Key k)
//     {
//         return data.get(k);
//     }

//     Value* opBinaryRight(string op)(Key k) if (op == "in")
//     {
//         return data.has(k);
//     }

//     void opIndexAssign(Value v, Key k)
//     {
//         data.set(k, v);
//     }
// }

class Map(Key, Value)
{
    alias This = typeof(this);
    This left;
    This right;
    Key key;
    Value value;
    size_t length;

    @disable this();

    this(typeof(null) n) {
        
    }

    int opApply(int delegate(Value) dg)
    {
        if (left !is null && left.opApply(dg))
        {
            return 1;
        }
        if (length != 0 && dg(value))
        {
            return 1;
        }
        if (right !is null && right.opApply(dg))
        {
            return 1;
        }
        return 0;
    }

    int opApply(int delegate(Key, Value) dg)
    {
        if (left !is null && left.opApply(dg))
        {
            return 1;
        }
        if (length != 0 && dg(key, value))
        {
            return 1;
        }
        if (right !is null && right.opApply(dg))
        {
            return 1;
        }
        return 0;
    }

    void opIndexAssign(Value v, Key k)
    {
        if (length == 0)
        {
            key = k;
            value = v;
            length = 1;
            left = new This;
            right = new This;
            // writeln("  new: ", value);
        }
        else
        {
            int c = compare(key, k);
            if (c > 0)
            {
                // writeln("  -> right");
                right[k] = v;
                length = left.length + right.length;
            }
            else if (c < 0)
            {
                // writeln("  -> left");
                left[k] = v;
                length = left.length + right.length;
            }
            else
            {
                key = k;
                value = v;
            }
        }
    }

    Value* opBinaryRight(string op)(Key k) if (op == "in")
    {
        int c = compare(key, k);
        if (c > 0)
        {
            if (right is null)
            {
                return null;
            }
            return right.has(k);
        }
        else if (c < 0)
        {
            if (left is null)
            {
                return null;
            }
            return left.has(k);
        }
        else
        {
            return &key;
        }
    }

    ref Value opIndex(Key k)
    {
        int c = compare(key, k);
        if (c > 0)
        {
            return right[k];
        }
        else if (c < 0)
        {
            return left[k];
        }
        else
        {
            return value;
        }
    }
}
