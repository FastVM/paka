module paka.walk;

import purr.base;
import purr.ast;

Node delegate(Node[])[string] pakaTransforms()
{
    Node delegate(Node[])[string] ret;
    ret["@paka.dotmap-pre"] = x => x.walkDotmap!"_pre_map";
    ret["@paka.dotmap-lhs"] = x => x.walkDotmap!"_lhs_map";
    ret["@paka.dotmap-rhs"] = x => x.walkDotmap!"_rhs_map";
    ret["@paka.dotmap-both"] = x => x.walkDotmap!"_both_map";
    return ret;
}

Node walkDotmap(string s)(Node[] args)
{
    static if (s == "_pre_map")
    {
        Node[] xy = [new Ident("_rhs")];
        Node lambdaBody = new Call([args[0]] ~ xy);
        Call lambda = new Call(new Ident("@fun"), [new Call(xy), lambdaBody]);
        Call domap = new Call(new Ident(s), [cast(Node) lambda] ~ args[1 .. $]);
        return domap;
    }
    else
    {
        Node[] xy = [new Ident("_lhs"), new Ident("_rhs")];
        Node lambdaBody = new Call(args[0 .. $ - 2] ~ xy);
        Call lambda = new Call(new Ident("@fun"), [new Call(xy), lambdaBody]);
        Call domap = new Call(new Ident(s), [cast(Node) lambda] ~ args[$ - 2 .. $]);
        return domap;
    }
}