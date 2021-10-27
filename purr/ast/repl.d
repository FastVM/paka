module purr.ast.repl;

import purr.srcloc;
import purr.ast.ast;
import purr.ast.lift;
import purr.parse;

Node replify(ref Node[] state, Node initNode) {
	Node[] lastVals = state;
	Node[] after;
	Node pre = SrcLoc.init.parse("paka.prelude");
	{
		Lifter pl = new Lifter;
		pl.liftProgram(pre);
		Lifter ll = new Lifter;
		ll.liftProgram(new Form("do", state, pre, initNode));
		foreach(name, get; ll.locals) {
			if (name == "this" || name == "repl.out" || name in pl.locals) {
				continue;
			}
			after ~= new Form("set", new Form("index", new Ident("this"), new Value(name)), get);
		}
		state = null;
		foreach (name, get; ll.locals) {
			if (name == "this" || name == "repl.out" || name in pl.locals) {
				continue;
			}
			state ~= new Form("var", new Ident(name), new Form("index", new Ident("this"), new Value(name)));
		}
	}
	Node lambdaBody = new Form("do", lastVals, new Form("var", new Ident("repl.return"), initNode), after, new Ident("repl.return"));
	Node mainLambda = new Form("lambda", new Form("args"), lambdaBody);
	Node setFinal = new Form("var", new Ident("repl.out"), new Form("call", mainLambda));
	Node printAll = new Form("call", new Ident("println"), new Ident("repl.out"));
	Node isFinalNone = new Form("!=", new Ident("repl.out"), new Value(null));
	Node maybePrintAll = new Form("if", isFinalNone, printAll, new Value(null));
	Node doMain = new Form("do", pre, setFinal, maybePrintAll);
	return doMain;
}
