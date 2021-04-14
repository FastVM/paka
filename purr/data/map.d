module purr.data.map;

import core.memory;
import purr.error;
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

class MapImpl(Key, Value)
{
    alias This = Map!(Key, Value);
    shared This leftv;
    shared This rightv;
    shared Key key = void;
    shared Value value = void;
    shared size_t length;
    long children;

    this(typeof(null) n = null) shared
    {
        length = 0;
        children = 0;
    }

    this(shared This l, shared This r, Key k, Value v) shared
    {
        right = r;
        left = l;
        key = k;
        value = v;
        length = left.length + right.length + 1;
        children = max(left.children, right.children) + 1;
    }
    
    ref shared(This) left() shared
    {
        if (leftv is null)
        {
            leftv = new shared This;
        }
        return leftv;
    }

    ref shared(This) right() shared
    {
        if (rightv is null)
        {
            rightv = new shared This;
        }
        return rightv;
    }

    int opApply(int delegate(Value) dg) shared
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

    int opApply(int delegate(shared Key, shared Value) dg) shared
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

    void rebalance() shared
    {
        if (left.children - 1 > right.children)
        {
            shared This left2 = left;
            shared This right2 = right;
            left = left2.left;
            right = new shared This(left2.right, right2, key, value);
            key = left2.key;
            value = left2.value;
            assert(length == right.length + left.length + 1);
            length = right.length + left.length + 1;
            children = max(left.children, right.children) + 1;
        }
        if (right.children - 1 > left.children)
        {
            shared This left2 = left;
            shared This right2 = right;
            left = new shared This(left2, right2.left, key, value);
            right = right2.right;
            key = right2.key;
            value = right2.value;
            assert(length == right.length + left.length + 1);
            length = right.length + left.length + 1;
            children = max(left.children, right.children) + 1;
        }
    }

    shared(Value) opIndex(shared Key k) shared
    {
        return *(k in this);
    }

    void opIndexAssign(shared Value v, shared Key k) shared
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

    shared(Value*) opBinaryRight(string op : "in")(Key k) shared
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
