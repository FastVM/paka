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
            return new Form("do", value, new Value(true));
        }
        Node setter = new Form("set", id, value);
        return new Form("do", setter, new Value(true));
    }
    else if (Value val = cast(Value) pattern)
    {
        return new Form("call", new Value(native!matchExact), [pattern, val]);
    }
    else if (Form call = cast(Form) pattern)
    {
        switch (call.form)
        {
        default:
            return new Form("call", new Value(native!matchExact), [value, pattern]);
        case ":":
            Node c1 = matcher(value, call.args[0]);
            Node c2 = matcher(value, call.args[1]);
            return new Form("&&", c1, c2);
        case "|":
            Node c1 = matcher(value, call.args[0]);
            Node c2 = call.args[1];
            return new Form("&&", c1, c2);
        case "tuple":
            goto case;
        case "array":
            Node[] pre;
            Node[] post;
            foreach (val; call.args)
            {
                if (Form call2 = cast(Form) val)
                {
                    if (call2.form == "..")
                    {
                        post ~= val;
                        continue;
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
                Node ret = new Form("call", new Value(native!matchExactLength),
                        [value, new Value(pre.length)]);
                foreach (index, term; pre)
                {
                    Node indexed = new Form("index", [
                            value, new Value(index)
                            ]);
                    ret = new Form("&&", [
                            ret, matcher(indexed, term)
                            ]);
                }
                return ret;
            }
            else
            {
                Node ret = new Form("call", new Value(native!matchNoLessLength),
                        [value, new Value(pre.length + post.length - 1)]);
                foreach (index, term; pre)
                {
                    Node indexed = new Form("index", [
                            value, new Value(index)
                            ]);
                    ret = new Form("&&", [
                            ret, matcher(indexed, term)
                            ]);
                }
                Node sliced = new Form("call", new Value(native!slice), [
                        value, new Value(pre.length), new Value(post.length-1)
                        ]);
                Form term0 = cast(Form) post[0];
                assert(term0);
                ret = new Form("&&", [
                        ret, matcher(sliced, term0.args[0])
                        ]);
                foreach (index, term; post[1 .. $])
                {
                    Node indexed = new Form("call", new Value(native!rindex),
                            [value, new Value(index + 1)]);
                    ret = new Form("&&", [
                            ret, matcher(indexed, term)
                            ]);
                }
                return ret;
            }
        }
        return new Form("call", new Value(native!matchExact), [pattern, call]);
    }
    else
    {
        assert(false);
    }
}
