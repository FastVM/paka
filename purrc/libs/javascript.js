let libs = {};

libs.io = {};

libs.io.print = console.log;

let lib = function(arg) {
    return libs[arg];
}

lib.indexOp = (x, y) => x[y];

lib.ltOp = (x, y) => x < y;
lib.addOp = (x, y) => x + y;
lib.subOp = (x, y) => x - y;

module.exports = lib;