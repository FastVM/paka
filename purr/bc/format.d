module purr.bc.format;

import purr.vm.bytecode;

alias Format = string;

enum Format[Opcode] format() {
	Format[Opcode] ret;
    ret[Opcode.exit] = "";
    ret[Opcode.store_reg] = "rr";
    ret[Opcode.store_byte] = "rb";
    ret[Opcode.store_int] = "ri";
    ret[Opcode.store_fun] = "rjf";
    ret[Opcode.fun_done] = "";
    ret[Opcode.equal] = "rrr";
    ret[Opcode.equal_num] = "rri";
    ret[Opcode.not_equal] = "rrr";
    ret[Opcode.not_equal_num] = "rri";
    ret[Opcode.less] = "rrr";
    ret[Opcode.less_num] = "rri";
    ret[Opcode.greater] = "rrr";
    ret[Opcode.greater_num] = "rri";
    ret[Opcode.less_than_equal] = "rrr";
    ret[Opcode.less_than_equal_num] = "rri";
    ret[Opcode.greater_than_equal] = "rrr";
    ret[Opcode.greater_than_equal_num] = "rri";
    ret[Opcode.jump_always] = "j";
    ret[Opcode.jump_if_false] = "jr";
    ret[Opcode.jump_if_true] = "jr";
    ret[Opcode.jump_if_equal] = "jrr";
    ret[Opcode.jump_if_equal_num] = "jri";
    ret[Opcode.jump_if_not_equal] = "jrr";
    ret[Opcode.jump_if_not_equal_num] = "jri";
    ret[Opcode.jump_if_less] = "jrr";
    ret[Opcode.jump_if_less_num] = "jri";
    ret[Opcode.jump_if_greater] = "jrr";
    ret[Opcode.jump_if_greater_num] = "jri";
    ret[Opcode.jump_if_less_than_equal] = "jrr";
    ret[Opcode.jump_if_less_than_equal_num] = "jri";
    ret[Opcode.jump_if_greater_than_equal] = "jrr";
    ret[Opcode.jump_if_greater_than_equal_num] = "jri";
    ret[Opcode.inc] = "rr";
    ret[Opcode.inc_num] = "ri";
    ret[Opcode.dec] = "rr";
    ret[Opcode.dec_num] = "ri";
    ret[Opcode.add] = "rrr";
    ret[Opcode.add_num] = "rri";
    ret[Opcode.sub] = "rrr";
    ret[Opcode.sub_num] = "rri";
    ret[Opcode.mul] = "rrr";
    ret[Opcode.mul_num] = "rri";
    ret[Opcode.div] = "rrr";
    ret[Opcode.div_num] = "rri";
    ret[Opcode.mod] = "rrr";
    ret[Opcode.mod_num] = "rri";
    ret[Opcode.static_call0] = "rj";
    ret[Opcode.static_call1] = "rjr";
    ret[Opcode.static_call2] = "rjrr";
    ret[Opcode.static_call] = "rjc";
    ret[Opcode.rec0] = "r";
    ret[Opcode.rec1] = "rr";
    ret[Opcode.rec2] = "rrr";
    ret[Opcode.rec] = "rc";
    ret[Opcode.call0] = "rr";
    ret[Opcode.call1] = "rrr";
    ret[Opcode.call2] = "rrrr";
    ret[Opcode.call] = "rrc";
    ret[Opcode.ret] = "r";
    ret[Opcode.println] = "r";
    ret[Opcode.putchar] = "r";
    ret[Opcode.array] = "rc";
    ret[Opcode.length] = "rr";
    ret[Opcode.index] = "rrr";
    ret[Opcode.syscall] = "rr";
	return ret;
}
