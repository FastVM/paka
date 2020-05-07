module lang.data.rope;

import std.algorithm;
import std.stdio;

double maxdiff = 64;

class Rope(T)
{
    Rope left = null;
    Rope right = null;
    T value = T.init;
    size_t length = 0;
    this()
    {
    }

    this(T s) {
        value = s;
        length = 1;
    }

    this(Rope l, Rope r)
    {
        left = l;
        right = r;
        size_t s;
        if (left !is null) {
            s += left.length;
        } 
        if (right !is null) {
            s += right.length;
        } 
        length = s;
    }

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

    this(Rope c)
    {
        if (c !is null) {
            left = c.left;
            right = c.right;
            value = c.value;
            length = c.length;
        }
    }

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

    const T opIndex(size_t index)
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

    const Rope!T opSlice(size_t from, size_t to) {
        if (from == to) {
            return new Rope;
        }
        if (length == 1 || (from == 0 && to == length)) {
            return new Rope(this);
        }
        if (left.length > to) {
            return left[from..to];
        }
        if (left.length <= from) {
            return right[from-left.length..to-left.length];
        }
        return left[from..left.length] ~ right[0..to-left.length];
    }

    alias opDollar = length;

    Rope opBinary(string s, T2)(T2 other) if (s == "~")
    {
        return this ~ new Rope(other);
    }

    Rope opBinary(string s)(Rope other) if (s == "~")
    {
        return new Rope(this, other).balanced;
    }

    void wscheme(size_t d = 0) {
        foreach (i; 0..d) {
            write("  ");
        }
        if (length == 1) {
            writeln(value);
        }
        else {
            writeln("concat");
            left.wscheme(d+1);
            right.wscheme(d+1);
        }
    }

    override int opCmp(Object other) {
        return array.cmp((cast(Rope!T) other).array);        
    }

    override bool opEquals(Object other) {
        Rope!T rope = cast(Rope) other;
        return length == rope.length && array == rope.array;
    }

    T[] array() const nothrow
    {
        T[] ret;
        extend(ret);
        return ret;
    }
}

Rope!T balanced(T)(Rope!T rope)
{
    if (rope.left is null || rope.right is null) {
        if (rope.left !is null) {
            return new Rope!T(rope.left);
        }
        if (rope.right !is null) {
            return new Rope!T(rope.right);
        }
        return rope;
    }
    double l = cast(double) rope.left.length;
    double r = cast(double) rope.right.length;
    if (l / r > maxdiff && rope.left.right !is null) {
        return new Rope!T(rope.left.left, rope.left.right ~ rope.right);
    }
    if (r / l > maxdiff && rope.right.left !is null) {
        return new Rope!T(rope.left ~ rope.right.left, rope.right.right);
    }
    return rope;
}
