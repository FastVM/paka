module lang.data.map;

import core.memory;
import lang.error;
import std.algorithm;
import std.stdio;
import std.conv;

struct Map(Key, Value) {
    struct Pair {
        Key key;
        Value value;
    }
    Pair[] pairs;

    size_t length() {
        return pairs.length;
    }

    int opApply(int delegate(Value) dg)
    {
        foreach (i; pairs) {
            if (int res = dg(i.value)) {
                return res;
            }
        }
        return 0;
    }

    int opApply(int delegate(Key, Value) dg)
    {
        foreach (i; pairs) {
            if (int res = dg(i.key, i.value)) {
                return res;
            }
        }
        return 0;
    }

    void opIndexAssign(Value v, Key k)
    {
        foreach (ref pair; pairs) {
            if (k == pair.key) {
                pair.value = v; 
                return;            
            }
        }
        pairs ~= Pair(k, v);
    }

    Value opIndex(Key k) {
        return *(k in this);
    }

    Value* opBinaryRight(string op)(Key k) if (op == "in")
    {
        foreach (ref pair; pairs) {
            if (k == pair.key) {
                return &pair.value;            
            }
        }
        return null;
    }

    string toString() 
    {
        return pairs.to!string;
    }
}
