module purr.ast.lift;

import std.array;
import std.stdio;
import std.algorithm;
import purr.err;
import purr.ast.ast;

class Lifter {
	Form[string] locals;
	string[] captures;
	Node[] nodes;
	Node captureSymbol;
	Node[string] pre; 
	size_t depth;

	this() {
		captureSymbol = new Ident("rec");
		locals["this"] = new Form("do", new Ident("this"));
	}

	Node liftProgram(Node node) {
		Node lifted = lift(node);
		// writeln(lifted);
		return new Form("do", pre.values.array, lifted);
	}

	Node lift(Node node) {
		nodes ~= node;
        scope (exit) {
            nodes.length--;
        }
        final switch (node.id) {
        case NodeKind.base:
            assert(false);
        case NodeKind.call:
            return liftExact(cast(Form) node);
        case NodeKind.ident:
            return liftExact(cast(Ident) node);
        case NodeKind.value:
            return liftExact(cast(Value) node);
        }
	}

	Node liftExact(Ident id) {
		if (Form* ret = id.repr in locals) {
			return cast(Node) *ret;
		}
		if (depth == 0) {
			vmError("global name resolution fail for: " ~ id.repr);
		}
		foreach (index, capture; captures) {
			if (capture == id.repr) {
				locals[id.repr] = new Form("deref", new Form("index", captureSymbol, new Value(cast(double)(index + 1))));
				return locals[id.repr];
			}
		}
		captures ~= id.repr;
		locals[id.repr] = new Form("deref", new Form("index", captureSymbol, new Value(cast(double) captures.length)));
		return locals[id.repr];
	}

	Node liftExact(Value val) {
		return cast(Node) val;
	}

	Node liftExact(Form form) {
		switch (form.form) {
		case "lambda":
			depth++;
			scope(exit) {
				depth--;
			}
			Form[string] oldLocals = locals;
			locals = ["rec": new Form("do", new Ident("rec"))];
			scope(exit) {
				locals = oldLocals;
			}
			Node[string] oldPre = pre;
			pre = null;
			scope(exit) {
				pre = oldPre;
			}
			string[] oldCaptures = captures;
			captures = null;
			scope(exit) {
				captures = oldCaptures;
			}
			Form argsForm = cast(Form) form.getArg(0);
			if (form is null) {
				vmError("malformed ast");
			}
			foreach (arg; argsForm.args) {
				if (Ident id = cast(Ident) arg) {
					locals[id.repr] = new Form("do", arg);
				}
			}
			Node lambdaBody = lift(form.getArg(1));
			Node[] captureNodes;
			foreach (capture; captures) {
				if (capture !in oldLocals) {
					captureNodes ~= new Form("ref", new Ident(capture));
				} else {
					captureNodes ~= new Form("ref", new Ident(capture));
				}
			}
			Node lambda = new Form("lambda", new Form("args", argsForm.args), pre.values.array, lambdaBody);
			Node built = new Form("array", lambda, captureNodes);
			return built;
		case "var":
			Node input = lift(form.getArg(1));
			Ident id = cast(Ident) form.getArg(0);
			Node output;
			if (Form* poutput = id.repr in locals) {
				output = poutput.args[0];
			} else { 
				locals[id.repr] = new Form("do", id);
				output = id;
				pre[id.repr] = new Form("var", output, new Value(null));
			}
			return cast(Node) new Form("set", output, input);
		default:
			Node[] args;
			foreach (arg; form.args) {
				args ~= lift(arg);
			}
			return cast(Node) new Form(form.form, args);
		}
	}
}