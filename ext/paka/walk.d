module paka.walk;

import purr.base;
import purr.ast.ast;

Node binaryFold(Node[] args)
{
    Node[] xy = [new Ident("_lhs"), new Ident("_rhs")];
    Node lambdaBody = new Call(args[0 .. $ - 2] ~ xy);
    Call lambda = new Call(new Ident("@fun"), [new Call(xy), lambdaBody]);
    Call domap = new Call(new Ident("_paka_fold"), [cast(Node) lambda] ~ args[$ - 2 .. $]);
    return domap;
}

Node binaryDotmap(string s)(Node[] args)
{
    Node[] xy = [new Ident("_lhs"), new Ident("_rhs")];
    Node lambdaBody = new Call(args[0 .. $ - 2] ~ xy);
    Call lambda = new Call(new Ident("@fun"), [new Call(xy), lambdaBody]);
    Call domap = new Call(new Ident(s), [cast(Node) lambda] ~ args[$ - 2 .. $]);
    return domap;
}