module purr.data.rope;

import std.algorithm;
import purr.io;

/// the maximum difference for a rope to rebalance
enum double maxdiff = 64;

/// an immutable array
/// currently the implementation is not very good
struct Rope(T)
{
    /// left hand side of the rope, may be null
    Rope* left = null;
    /// right hand side of the rope, may be null
    Rope* right = null;
    /// the value is always there, even if it is not used
    T value = T.init;
    /// to make length O(1)
    size_t length = 0;

    /// construct a rope with length 1
    this(T s)
    {
        value = s;
        length = 1;
    }

    /// construct a rope from two other ropes
    /// this does not rebalance
    this(Rope l, Rope r)
    {
        left = new Rope(l);
        right = new Rope(r);
        size_t s;
        if (left !is null)
        {
            s += left.length;
        }
        if (right !is null)
        {
            s += right.length;
        }
        length = s;
    }

    /// constructs a rope from an iterable datastructure
    this(T2)(T2 a)
    {
        if (a.length != 0)
        {
            size_t l = 0;
            size_t r = a.length;
            length = r - l;
            if ((r - l) > 1)
            {
                size_t m = (r + l) / 2;
                left = new Rope(a, l, m);
                right = new Rope(a, m, r);
            }
            else
            {
                left = null;
                right = null;
                value = a[l];
            }
        }
    }

    /// duplicates a rope
    this(Rope* c)
    {
        if (c !is null)
        {
            left = c.left;
            right = c.right;
            value = c.value;
            length = c.length;
        }
    }

    /// usually used internally, it constructs a rope from a slice of another ropes
    this(T2)(T2 a, size_t l = 0, size_t r = 0)
    {
        if (r == l)
        {
            r = a.length;
        }
        length = r - l;
        if ((r - l) > 1)
        {
            size_t m = (r + l) / 2;
            left = new Rope(a, l, m);
            right = new Rope(a, m, r);
        }
        else
        {
            left = null;
            right = null;
            value = a[l];
        }
    }

    /// appends data of rope into native array, similar to recursive array
    const void extend(ref T[] arr) nothrow
    {
        if (left is null && right is null)
        {
            if (length != 0)
            {
                arr ~= value;
            }
            return;
        }
        left.extend(arr);
        right.extend(arr);
    }

    /// gets index of element in rope, does not check bounds 
    const T opIndex(size_t index) nothrow
    {
        if (left is null && right is null)
        {
            return value;
        }
        if (index < left.length)
        {
            return left[index];
        }
        return right[index - left.length];
    }

    /// slices rope into new rope, does not check bounds 
    const Rope!T opSlice(size_t from, size_t to)
    {
        if (from == to)
        {
            return new Rope;
        }
        if (length == 1 || (from == 0 && to == length))
        {
            return new Rope(this);
        }
        if (left.length > to)
        {
            return left[from .. to];
        }
        if (left.length <= from)
        {
            return right[from - left.length .. to - left.length];
        }
        return left[from .. left.length] ~ right[0 .. to - left.length];
    }

    /// they are equivalent in this case 
    alias opDollar = length;

    /// concatenate with balancing to a non rope
    Rope opBinary(string s, T2)(T2 other) if (s == "~")
    {
        return this ~ new Rope(other);
    }

    /// concatenate with balancing 
    Rope opBinary(string s)(Rope other) if (s == "~")
    {
        return new Rope(this, other).balanced;
    }

    /// compares two ropes like strings would
    int opCmp(Object other)
    {
        return array.cmp((cast(Rope!T) other).array);
    }

    /// compares two ropes element for element
    bool opEquals(Object other)
    {
        Rope!T rope = cast(Rope) other;
        return length == rope.length && array == rope.array;
    }

    /// turns rope into array
    T[] array() const nothrow
    {
        T[] ret;
        extend(ret);
        return ret;
    }

    int opApply(int delegate(T) dg)
    {
        if (left is null && right is null)
        {
            if (length != 0)
            {
                if (int res = dg(value))
                {
                    return res;
                }
            }
            return 0;
        }
        else
        {
            if (int res = left.opApply(dg))
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
}

/// balances a rope
Rope!T balanced(T)(Rope!T rope)
{
    if (rope.left is null || rope.right is null)
    {
        if (rope.left !is null)
        {
            return new Rope!T(rope.left);
        }
        if (rope.right !is null)
        {
            return new Rope!T(rope.right);
        }
        return rope;
    }
    double l = cast(double) rope.left.length;
    double r = cast(double) rope.right.length;
    if (l / r > maxdiff && rope.left.right !is null)
    {
        return new Rope!T(rope.left.left, rope.left.right ~ rope.right);
    }
    if (r / l > maxdiff && rope.right.left !is null)
    {
        return new Rope!T(rope.left ~ rope.right.left, rope.right.right);
    }
    return rope;
}
