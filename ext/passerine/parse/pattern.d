module ext.passerine.parse.pattern;

import purr.io;
import std.conv;
import purr.ast.ast;
import purr.dynamic;

Dynamic matchExact(Args args)
{
    return dynamic(args[0] == args[1]);
}

bool isIndexable(Dynamic arg)
{
    return arg.isArray;
}

Dynamic matchExactLength(Args args)
{
    return dynamic(args[0].isIndexable && args[0].arr.length == args[1].as!size_t);
}

Dynamic matchNoLength(Args args)
{
    return dynamic(args[0].isIndexable && args[0].arr.length == 0);
}

Dynamic matchNoLessLength(Args args)
{
    return dynamic(args[0].isIndexable && args[0].arr.length >= args[1].as!size_t);
}

Dynamic rindex(Args args)
{
    return args[0].arr[$ - args[1].as!size_t];
}

Dynamic slice(Args args)
{
    return args[0].arr[args[1].as!size_t .. $ - args[2].as!size_t].dynamic;
}

Node matcher(Node value, Node pattern, size_t line = __LINE__)
{
    assert(pattern !is null, "null pattern at: " ~ line.to!string);
    if (Ident id = cast(Ident) pattern)
    {
        if (id.repr == "_")
        {
            return new Form("do", value, new Value(true));
        }
        Node setter = new Form("set", id, value);
        return new Form("do", setter, new Value(true));
    }
    else if (cast(Value) pattern)
    {
        return new Form("==", pattern, value);
    }
    else if (Form call = cast(Form) pattern)
    {
        switch (call.form)
        {
        default:
            return new Form("call", new Value(native!matchExact), [
                    value, pattern
                    ]);
        case ":":
            Node c1 = matcher(value, call.args[0]);
            Node c2 = matcher(value, call.args[1]);
            return new Form("&&", c1, c2);
        case "|":
            Node c1 = matcher(value, call.args[0]);
            Node c2 = call.args[1];
            return new Form("&&", c1, c2);
        case "tuple":
            if (call.args.length == 0)
            {
                return new Form("==", new Value(Dynamic(cast(Dynamic[]) null)), value);
            }
            goto arrayLike;
        case "array":
            if (call.args.length == 0)
            {
                return new Form("==", new Value(Dynamic.tuple(null)), value);
            }
        arrayLike:
            Node[] pre;
            Node mid = null;
            Node[] post;
            foreach (val; call.args)
            {
                if (Form call2 = cast(Form) val)
                {
                    if (call2.form == "..")
                    {
                        mid = val;
                        continue;
                    }
                }
                if (mid !is null)
                {
                    post ~= val;
                }
                else
                {
                    pre ~= val;
                }
            }
            if (mid is null)
            {
                Node ret = new Form("call", new Value(native!matchExactLength),
                        [value, new Value(pre.length)]);
                foreach (index, term; pre)
                {
                    Node indexed = new Form("index", [value, new Value(index)]);
                    ret = new Form("&&", [ret, matcher(indexed, term)]);
                }
                return ret;
            }
            else
            {
                Node ret = new Form("call", new Value(native!matchNoLessLength),
                        [value, new Value(pre.length + post.length)]);
                foreach (index, term; pre)
                {
                    Node indexed = new Form("index", [value, new Value(index)]);
                    ret = new Form("&&", [ret, matcher(indexed, term)]);
                }
                Node sliced = new Form("call", new Value(native!slice), [
                        value, new Value(pre.length), new Value(post.length)
                        ]);
                Form term0 = cast(Form) mid;
                assert(term0);
                ret = new Form("&&", [ret, matcher(sliced, term0.args[0])]);
                foreach (index, term; post)
                {
                    Node indexed = new Form("call", new Value(native!rindex),
                            [value, new Value(index + 1)]);
                    ret = new Form("&&", [ret, matcher(indexed, term)]);
                }
                return ret;
            }
        case "call":
            return new Form("call", new Value(native!matchExact), [
                    pattern, call
                    ]);
        }
    }
    assert(false);
}
