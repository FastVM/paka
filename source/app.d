void main(string[] args) {
	import lisp.vm: run;
	import lisp.base: loadBase;
	import lisp.walk: Walker;
	import lisp.parse: Node, parse;
	import lisp.bytecode: Function;
	import lisp.base: loadBase;
	import std.stdio: writeln;
	import std.file: read;
	string code = cast(string) args[1].read;
	code = "(do " ~ code ~ ")";
	Node node = code.parse;
	Walker walker = new Walker;
	Function func = walker.walkProgram(node);
	func.captured = loadBase;
	run(func, null);
}