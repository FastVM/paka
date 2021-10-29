module purr.ast.note;

import std.stdio;
import std.conv;
import purr.err;
import purr.srcloc;
import purr.ast.ast;

void annotate(Node src) {
	final switch (src.id) {
	case NodeKind.base:
		vmError("err");
		assert(false);
	case NodeKind.call:
		annotateExact(cast(Form) src);
		break;
	case NodeKind.ident:
		annotateExact(cast(Ident) src);
		break;
	case NodeKind.value:
		annotateExact(cast(Value) src);
		break;
	}
}

void annotateExact(Form form) {
	foreach (arg; form.args) {
		annotate(arg);
	}
}

void annotateExact(Ident id) {
}

void annotateExact(Value val) {
}
