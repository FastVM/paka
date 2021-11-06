module purr.ast.repl;

import purr.srcloc: SrcLoc;
import purr.ast.ast: Node, Form, Ident, Value;
import purr.ast.lift: Lifter;
import purr.parse: parse;

Node replify(ref Node[] state, Node initNode) {
    return initNode;
}
