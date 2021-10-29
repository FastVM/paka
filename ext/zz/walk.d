module ext.zz.walk;

import std.stdio;
import purr.ast.ast;

class Macros {
    size_t calls;
    int depth;

    this(size_t c = size_t.max) {
        calls = c;
    }

    void walk(Node src, ref Node dest) {
        // foreach (i; 0..depth) {
        //     write("| ");
        // }
        // writeln(src);
        depth++;
        if (calls == 0) {
            dest = src;
        } else {
            calls--;
            if (Form form = cast(Form) src) {
                Form ret = new Form(form.form, form.args);
                dest = cast(Node) ret;
                foreach (ind, arg; form.args) {
                    walk(arg, ret.getArg(ind));
                }
            } else {
                dest = cast(Node) src;
            }
        }
        depth--;
        // foreach (i; 0..depth) {
        //     write("| ");
        // }
        // write("= ");
        // writeln(src);
    }
}