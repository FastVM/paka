module ext.zz.parse;

import std.stdio;
import std.algorithm;
import purr.srcloc;
import purr.err;
import purr.ast.ast;
import ext.zz.zrepr;
import std.conv;

enum special = ["+", "-", "*", "/", "%", "&&", "||", "<", ">", "<=", ">=", "==", "!=", "do", "if", "while", "lambda", "return", "array", "def", "set", "var", "index", "call", "args", "macro"];
enum ops = ["+", "-", "*", "/", "%"];

int indentc(string line) {
	int ind = 0;
	while (true) {
		if (line.length == 0) {
			return 0;
		}
		if (line[0] != ' ') {
			return ind;
		}
		ind += 1;
		line = line[1..$];
	}
}

alias Thunk = void delegate();

Node parseLines(string[] lines) {
	Form[int] calls = [0: new Form("do")];
	Thunk[] todo;
	for (int i = 0; i < lines.length; i++) {
		int indent = indentc(lines[i]);
		string[] words = [""];
		int[] spaces = [];
		foreach (j, c; lines[i]) {
			if (c == ' ') {
				if (words[$-1].length != 0) {
					spaces ~= cast(int) j + 1;
					words.length += 1;
				}
			} else {
				words[$-1] ~= c;
			}
		}
		if (words[0].length == 0) {
			continue;
		} 
		if (words[$-1].length == 0) {
			words.length --;
		}
		Form[int] lastCalls = calls;
		calls = null;
		Node arg;
		if ('0' <= words[$-1][0] && words[$-1][0] <= '9') {
			arg = cast(Node) new Value(words[$-1].to!double);
		} else if (words[$-1] == "null") {
			arg = cast(Node) new Value(null);
		} else {
			arg = cast(Node) new Ident(words[$-1]);
		}
		foreach_reverse(j, item; words[0..$-1]) {
			Form next;
			if ('0' <= item[0] && item[0] <= '9') {
				vmError("cannot call number");
			} else if (item == ":") {
				Node rest = new Value(lines[i][spaces[j]..$]);
				next = new Form("do", rest);
			} else if (item == "debug") {
				Node curArg = arg;
				todo ~= {
					writeln(curArg.tozz);
				};
				next = new Form("do");
			} else if (special.canFind(item)) {
				next = new Form(item, arg);
			} else {
				next = new Form("call", new Ident(item), arg);
			}
			calls[spaces[j]] = next;
			arg = next;
		}
		foreach (k, lc; lastCalls) {
			if (k <= indent) {
				calls[k] = lc;
			}
		}
		if (Form* c = indent in calls) {
			if (ops.canFind(c.form) && c.args.length == 2) {
				Node lhs = c.args[$-1];
				Form nf = new Form(c.form, lhs, arg);
				c.args[$-1] = nf;
				*c = nf;
			} else {
				c.args ~= arg;
			}
		} else {
			vmError("indent error");
		}
	}
	foreach(t; todo) {
		t();
	}
	return calls[0];
}
