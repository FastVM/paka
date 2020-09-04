module lang.data.array;
import std.stdio;

struct SafeArray(T)
{
    T[] arr;
    alias arr this;
    ref T opIndex(size_t n)
    {
        if (n >= arr.length)
        {
            throw new Exception("index error: builtin");
        }
        return arr[n];
    }

    SafeArray!T opSlice(size_t from, size_t to)
    {
        if (from > arr.length || to > arr.length || from > to)
        {
            throw new Exception("index error: builtin");
        }
        return SafeArray!T(arr[from .. to]);
    }

    size_t opDollar()
    {
        return arr.length;
    }
}
