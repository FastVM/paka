module purr.ast.dis;

import std.algorithm;
import std.stdio;
import std.conv;

import purr.ast.ast;

import purr.err;
import purr.bc.instr;
import purr.bc.locs;
import purr.bc.opt;
import purr.vm.bytecode;
import purr.plugin.plugins;

class Dis {
	int[] regs;
	int[] labels;

	Node setReg(Argument arg, Node val) {
		int reg = arg.value.register.reg;
		if (regs.canFind(reg)) {
			return new Form("set", new Ident("r" ~ reg.to!string), val);
		} else {
			regs ~= reg;
			return new Form("var", new Ident("r" ~ reg.to!string), val);
		}
	}

	Node dis(Argument arg) {
		if (arg.type == Argument.Type.register) {
			return new Ident("r" ~ arg.value.register.reg.to!string);
		}
		if (arg.type == Argument.Type.byte_) {
			return new Value(arg.value.byte_.val.to!double);
		}
		if (arg.type == Argument.Type.integer) {
			return new Value(arg.value.integer.val.to!double);
		}
		if (arg.type == Argument.Type.function_) {
			int[] xregs = regs;
			int[] xlabels = labels;
			regs = null;
			labels = null;
			scope(exit) {
				regs = xregs;
				labels = xlabels;
			}
			Blocks blocks = Blocks.from(arg.value.function_.instrs);
			Node[] nodes;
			foreach (block; blocks.blocks) {
				nodes ~= new Form("do", new Form("label", new Ident("l" ~ block.firstOffset.to!string)), dis(block));
			}
			Node[] params;
			if (arg.value.function_.nregs == 0) {
				params = args(1);
			} else if (arg.value.function_.nregs <= 8) {
				params = args(arg.value.function_.nregs);
			} else {
				params = args(8);
			}
			Node func;
			if (nodes.length == 1) {
				func = new Form("lambda", new Form("args", params), nodes[0]);
			} else {
				func = new Form("lambda", new Form("args", params), new Form("do", nodes));
			}
			return new Form("var", new Ident("f" ~ arg.value.function_.instrs[0].offset.to!string), func);
		}
		vmError("cannot dis arg: " ~ arg.to!string);
		assert(false);
	}

	Node jump(Argument arg) {
		labels ~= arg.value.location.loc;
		return new Form("goto", new Ident("l" ~ arg.value.location.loc.to!string));
	}

	Node[] args(int nargs) {
		Node[] ret;
		foreach (i; 0..nargs) {
			ret ~= new Ident("r" ~ i.to!string);
			regs ~= i;
		}
		return ret;
	}

	Node call(Argument outReg, Node func, Argument[] iargs) {
		Node[] args = [func];
		foreach (arg; iargs) {
			args ~= new Ident("r" ~ arg.value.register.reg.to!string);
		}
		return setReg(outReg, new Form("call", args));
	}

	Node dis(Instr instr) {
		final switch (instr.op) {
		case Opcode.exit:
			return new Form("goto", new Ident("exit"));
		case Opcode.store_reg:
			return setReg(instr.args[0], dis(instr.args[1]));
		case Opcode.store_byte:
			return setReg(instr.args[0], dis(instr.args[1]));
		case Opcode.store_int:
			return setReg(instr.args[0], dis(instr.args[1]));
		case Opcode.store_fun:
			return setReg(instr.args[0], dis(instr.args[2]));
		case Opcode.fun_done:
			return null;
		case Opcode.equal:
			break;
		case Opcode.equal_num:
			break;
		case Opcode.not_equal:
			break;
		case Opcode.not_equal_num:
			break;
		case Opcode.less:
			break;
		case Opcode.less_num:
			break;
		case Opcode.greater:
			break;
		case Opcode.greater_num:
			break;
		case Opcode.less_than_equal:
			break;
		case Opcode.less_than_equal_num:
			break;
		case Opcode.greater_than_equal:
			break;
		case Opcode.greater_than_equal_num:
			break;
		case Opcode.jump_always:
			return jump(instr.args[0]);
		case Opcode.jump_if_false:
			return new Form("if", dis(instr.args[1]), new Value(0), jump(instr.args[0]));
		case Opcode.jump_if_true:
			return new Form("if", dis(instr.args[1]), jump(instr.args[0]), new Value(0));
		case Opcode.jump_if_equal:
			return new Form("if", new Form("==", dis(instr.args[1]), dis(instr.args[2])), jump(instr.args[0]));
		case Opcode.jump_if_equal_num:
			return new Form("if", new Form("==", dis(instr.args[1]), dis(instr.args[2])), jump(instr.args[0]));
		case Opcode.jump_if_not_equal:
			return new Form("if", new Form("!=", dis(instr.args[1]), dis(instr.args[2])), jump(instr.args[0]));
		case Opcode.jump_if_not_equal_num:
			return new Form("if", new Form("!=", dis(instr.args[1]), dis(instr.args[2])), jump(instr.args[0]));
		case Opcode.jump_if_less:
			return new Form("if", new Form("<", dis(instr.args[1]), dis(instr.args[2])), jump(instr.args[0]));
		case Opcode.jump_if_less_num:
			return new Form("if", new Form("<", dis(instr.args[1]), dis(instr.args[2])), jump(instr.args[0]));
		case Opcode.jump_if_greater:
			return new Form("if", new Form(">", dis(instr.args[1]), dis(instr.args[2])), jump(instr.args[0]));
		case Opcode.jump_if_greater_num:
			return new Form("if", new Form(">", dis(instr.args[1]), dis(instr.args[2])), jump(instr.args[0]));
		case Opcode.jump_if_less_than_equal:
			return new Form("if", new Form("<=", dis(instr.args[1]), dis(instr.args[2])), jump(instr.args[0]));
		case Opcode.jump_if_less_than_equal_num:
			return new Form("if", new Form("<=", dis(instr.args[1]), dis(instr.args[2])), jump(instr.args[0]));
		case Opcode.jump_if_greater_than_equal:
			return new Form("if", new Form(">=", dis(instr.args[1]), dis(instr.args[2])), jump(instr.args[0]));
		case Opcode.jump_if_greater_than_equal_num:
			return new Form("if", new Form(">=", dis(instr.args[1]), dis(instr.args[2])), jump(instr.args[0]));
		case Opcode.inc:
			return setReg(instr.args[0], new Form("+", dis(instr.args[0]), dis(instr.args[1])));
		case Opcode.inc_num:
			return setReg(instr.args[0], new Form("+", dis(instr.args[0]), dis(instr.args[1])));
		case Opcode.dec:
			return setReg(instr.args[0], new Form("-", dis(instr.args[0]), dis(instr.args[1])));
		case Opcode.dec_num:
			return setReg(instr.args[0], new Form("-", dis(instr.args[0]), dis(instr.args[1])));
		case Opcode.add:
			return setReg(instr.args[0], new Form("+", dis(instr.args[1]), dis(instr.args[2])));
		case Opcode.add_num:
			return setReg(instr.args[0], new Form("+", dis(instr.args[1]), dis(instr.args[2])));
		case Opcode.sub:
			return setReg(instr.args[0], new Form("-", dis(instr.args[1]), dis(instr.args[2])));
		case Opcode.sub_num:
			return setReg(instr.args[0], new Form("-", dis(instr.args[1]), dis(instr.args[2])));
		case Opcode.mul:
			return setReg(instr.args[0], new Form("*", dis(instr.args[1]), dis(instr.args[2])));
		case Opcode.mul_num:
			return setReg(instr.args[0], new Form("*", dis(instr.args[1]), dis(instr.args[2])));
		case Opcode.div:
			return setReg(instr.args[0], new Form("/", dis(instr.args[1]), dis(instr.args[2])));
		case Opcode.div_num:
			return setReg(instr.args[0], new Form("/", dis(instr.args[1]), dis(instr.args[2])));
		case Opcode.mod:
			return setReg(instr.args[0], new Form("%", dis(instr.args[1]), dis(instr.args[2])));
		case Opcode.mod_num:
			return setReg(instr.args[0], new Form("%", dis(instr.args[1]), dis(instr.args[2])));
		case Opcode.static_call0:
			return call(instr.args[0], new Ident("f" ~ to!string(instr.args[1].value.location.loc + 1)), instr.args[2..$]);
		case Opcode.static_call1:
			return call(instr.args[0], new Ident("f" ~ to!string(instr.args[1].value.location.loc + 1)), instr.args[2..$]);
		case Opcode.static_call2:
			return call(instr.args[0], new Ident("f" ~ to!string(instr.args[1].value.location.loc + 1)), instr.args[2..$]);
		case Opcode.static_call:
			return call(instr.args[0], new Ident("f" ~ to!string(instr.args[1].value.location.loc + 1)), instr.args[2..$]);
		case Opcode.rec0:
			return call(instr.args[0], new Ident("rec"), instr.args[1..$]);
		case Opcode.rec1:
			return call(instr.args[0], new Ident("rec"), instr.args[1..$]);
		case Opcode.rec2:
			return call(instr.args[0], new Ident("rec"), instr.args[1..$]);
		case Opcode.rec:
			return call(instr.args[0], new Ident("rec"), instr.args[1..$]);
		case Opcode.call0:
			return call(instr.args[0], dis(instr.args[1]), instr.args[2..$]);
		case Opcode.call1:
			return call(instr.args[0], dis(instr.args[1]), instr.args[2..$]);
		case Opcode.call2:
			return call(instr.args[0], dis(instr.args[1]), instr.args[2..$]);
		case Opcode.call:
			return call(instr.args[0], dis(instr.args[1]), instr.args[2..$]);
		case Opcode.ret:
			return new Form("return", dis(instr.args[0]));
		case Opcode.println:
			return new Form("call", new Ident("println"), dis(instr.args[0]));
		case Opcode.putchar:
			return new Form("call", new Ident("putchar"), dis(instr.args[0]));
		case Opcode.array:
			Node[] args;
			foreach (arg; instr.args[1].value.call.regs) {
				args ~= new Ident("r" ~ arg.to!string);
			}
			return setReg(instr.args[0], new Form("array", args));
		case Opcode.length:
			return setReg(instr.args[0], new Form("length", dis(instr.args[1])));
		case Opcode.index:
			return setReg(instr.args[0], new Form("index", dis(instr.args[1]), dis(instr.args[2])));
		case Opcode.syscall:
			return setReg(instr.args[0], new Form("call", new Ident("syscall"), dis(instr.args[1])));
		}
		vmError("dis: cannot dis instruction: " ~ instr.op.to!string);
		assert(false);
	}

	Node[] dis(Block block) {
		Node[] nodes;
		foreach (instr; block.instrs) {
			Node node = dis(instr);
			if (node !is null) {
				nodes ~= node;
			}
		}
		return nodes;
	}

	Node dis(Blocks blocks) {
		Node[] nodes;
		foreach (block; blocks.blocks) {
			nodes ~= new Form("do", new Form("label", new Ident("l" ~ block.firstOffset.to!string)), dis(block));
		}
		nodes ~= new Form("label", new Ident("exit"));
		return new Form("do", nodes);
	}
}
