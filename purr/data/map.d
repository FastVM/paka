module purr.data.map;

import core.memory;
import std.algorithm;
import purr.io;
import std.conv;

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

alias Map(K, V) = MapImpl!(K, V);

final class MapImpl(Key, Value)
{
    alias This = Map!(Key, Value);
    This leftv;
    This rightv;
    Key key = void;
    Value value = void;
    size_t length;
    long children;

    this(typeof(null) n = null)
    {
        length = 0;
        children = 0;
    }

    this(This l, This r, Key k, Value v)
    {
        right = r;
        left = l;
        key = k;
        value = v;
        length = left.length + right.length + 1;
        children = max(left.children, right.children) + 1;
    }

    ref This left()
    {
        if (leftv is null)
        {
            leftv = new This;
        }
        return leftv;
    }

    ref This right()
    {
        if (rightv is null)
        {
            rightv = new This;
        }
        return rightv;
    }

    int opApply(int delegate(Value) dg)
    {
        if (length != 0)
        {
            if (int res = left.opApply(dg))
            {
                return res;
            }
            if (int res = dg(value))
            {
                return res;
            }
            if (int res = right.opApply(dg))
            {
                return res;
            }
        }
        return 0;
    }

    int opApply(int delegate(Key, Value) dg)
    {
        if (length != 0)
        {
            if (int res = left.opApply(dg))
            {
                return res;
            }
            if (int res = dg(key, value))
            {
                return res;
            }
            if (int res = right.opApply(dg))
            {
                return res;
            }
        }
        return 0;
    }

    void rebalance()
    {
        if (left.children - 1 > right.children)
        {
            This left2 = left;
            This right2 = right;
            left = left2.left;
            right = new This(left2.right, right2, key, value);
            key = left2.key;
            value = left2.value;
            assert(length == right.length + left.length + 1);
            length = right.length + left.length + 1;
            children = max(left.children, right.children) + 1;
        }
        if (right.children - 1 > left.children)
        {
            This left2 = left;
            This right2 = right;
            left = new This(left2, right2.left, key, value);
            right = right2.right;
            key = right2.key;
            value = right2.value;
            assert(length == right.length + left.length + 1);
            length = right.length + left.length + 1;
            children = max(left.children, right.children) + 1;
        }
    }

    Value opIndex(Key k)
    {
        return *(k in this);
    }

    void opIndexAssign(Value v, Key k)
    {
        if (length == 0)
        {
            key = k;
            value = v;
            length = 1;
            children = 0;
        }
        else
        {
            int c = compare(key, k);
            if (c > 0)
            {
                left[k] = v;
                length = right.length + left.length + 1;
                children = max(left.children, right.children) + 1;
                rebalance;
            }
            else if (c < 0)
            {
                right[k] = v;
                length = right.length + left.length + 1;
                children = max(left.children, right.children) + 1;
                rebalance;
            }
            else
            {
                key = k;
                value = v;
            }
        }
    }

    Value* opBinaryRight(string op : "in")(Key k)
    {
        if (length == 0)
        {
            return null;
        }

        int c = compare(key, k);
        if (c > 0)
        {
            return k in left;
        }
        else if (c < 0)
        {
            return k in right;
        }
        else
        {
            return &value;
        }
    }

    override string toString()
    {
        return "Map(...)";
    }
}
