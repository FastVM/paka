module ext.passerine.parse.pattern;

import purr.io;
import purr.ast.ast;
import purr.dynamic;

Dynamic matchExact(Args args)
{
    return dynamic(args[0] == args[1]);
}

Dynamic matchExactLength(Args args)
{
    return dynamic(args[0].arr.length == args[1].as!size_t);
}

Dynamic matchNoLessLength(Args args)
{
    return dynamic(args[0].arr.length >= args[1].as!size_t);
}

Dynamic rindex(Args args)
{
    return args[0].arr[$ - args[1].as!size_t];
}

Dynamic slice(Args args)
{
    return args[0].arr[args[1].as!size_t .. $-args[2].as!size_t].dynamic;
}

Node matcher(Node value, Node pattern)
{
    if (Ident id = cast(Ident) pattern)
    {
        if (id.repr == "_")
        {
            return new Call("do", [value, new Value(true)]);
        }
        Node setter = new Call("set", [id, value]);
        return new Call("do", [setter, new Value(true)]);
    }
    else if (Value val = cast(Value) pattern)
    {
        return new Call(new Value(native!matchExact), [pattern, val]);
    }
    else if (Call call = cast(Call) pattern)
    {
        if (Ident id = cast(Ident) call.args[0])
        {
            switch (id.repr)
            {
            default:
                return new Call(new Value(native!matchExact), [value, pattern]);
            case ":":
                Node c1 = matcher(value, call.args[1]);
                Node c2 = matcher(value, call.args[2]);
                return new Call("&&", [c1, c2]);
            case "|":
                Node c1 = matcher(value, call.args[1]);
                Node c2 = call.args[2];
                return new Call("&&", [c1, c2]);
            case "tuple":
                goto case;
            case "array":
                Node[] pre;
                Node[] post;
                foreach (val; call.args[1 .. $])
                {
                    if (Call call2 = cast(Call) val)
                    {
                        if (Ident id2 = cast(Ident) call2.args[0])
                        {
                            if (id2.repr == "..")
                            {
                                post ~= val;
                                continue;
                            }
                        }
                    }
                    if (post.length != 0)
                    {
                        post ~= val;
                    }
                    else
                    {
                        pre ~= val;
                    }
                }
                if (post.length == 0)
                {
                    Node ret = new Call(new Value(native!matchExactLength),
                            [value, new Value(pre.length)]);
                    foreach (index, term; pre)
                    {
                        Node indexed = new Call("index", [
                                value, new Value(index)
                                ]);
                        ret = new Call("&&", [
                                ret, matcher(indexed, term)
                                ]);
                    }
                    return ret;
                }
                else
                {
                    Node ret = new Call(new Value(native!matchNoLessLength),
                            [value, new Value(pre.length + post.length - 1)]);
                    foreach (index, term; pre)
                    {
                        Node indexed = new Call("index", [
                                value, new Value(index)
                                ]);
                        ret = new Call("&&", [
                                ret, matcher(indexed, term)
                                ]);
                    }
                    Node sliced = new Call(new Value(native!slice), [
                            value, new Value(pre.length), new Value(post.length-1)
                            ]);
                    Call term0 = cast(Call) post[0];
                    assert(term0);
                    ret = new Call("&&", [
                            ret, matcher(sliced, term0.args[1])
                            ]);
                    foreach (index, term; post[1 .. $])
                    {
                        Node indexed = new Call(new Value(native!rindex),
                                [value, new Value(index + 1)]);
                        ret = new Call("&&", [
                                ret, matcher(indexed, term)
                                ]);
                    }
                    return ret;
                }
            }
        }
        return new Call(new Value(native!matchExact), [pattern, call]);
    }
    else
    {
        assert(false);
    }
}
