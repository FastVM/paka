#!/usr/bin/env node

const fs = require('fs');
const filename = process.argv[2];
const src = fs.readFileSync(filename);

let ctx = globalThis;
let objs = new Map();
let nobjs = 0;
let tmpstr = '';
let tmpargs = [];
let stdout = '';
let tbl;

const putchar = function(code) {
    if (code === 10) {
        console.log(stdout);
        stdout = '';
    } else {
        stdout += String.fromCharCode(code);
    }
    return 0;
};

const alloc = function() {
    nobjs += 1;
    objs[nobjs] = new Map();
    return nobjs;
};

const allocn = function(n) {
    nobjs += 1;
    objs[nobjs] = n;
    return nobjs;
};

const allocf = function(f) {
    nobjs += 1;
    let fun = tbl.get(f);
    objs[nobjs] = function() {
        let args = Array.prototype.map.call(arguments, function(a) {
            nobjs += 1;
            objs[nobjs] = a;
            return nobjs;
        });
        let res = fun.apply(null, args);
        // args.forEach(function(a) {
        //     delete objs[a];
        // });
        return objs[res];
    };
    return nobjs;
};

const allocs = function() {
    nobjs += 1;
    objs[nobjs] = tmpstr;
    return nobjs;
};

const objdup = function(ptr) {
    nobjs += 1;
    objs[nobjs] = objs[ptr];
    return nobjs;
};

const objrm = function(ptr) {
    delete objs[ptr];
}

const loadjs = function() {
    nobjs += 1;
    objs[nobjs] = ctx[tmpstr];
    return nobjs;
};

const tmpadd = function(chr) {
    tmpstr += String.fromCharCode(chr);
};

const tmpdel = function() {
    tmpstr = '';
};

const objsetptr = function(ptr, val) {
    objs[ptr][tmpstr] = val;
};

const objsetn = function(ptr, val, n) {
    objs[ptr][n] = objs[val];
}

const objgetptr = function(ptr) {
    nobjs += 1;
    objs[nobjs] = objs[ptr][tmpstr];
    return nobjs;
};

const objgetn = function(ptr, n) {
    nobjs += 1;
    objs[nobjs] = objs[ptr][n];
    return nobjs;
};

const objgetval = function(ptr) {
    return objs[ptr];
}

const objbind = function(ptr) {
    let obj = objs[ptr];
    let fun = obj[tmpstr];
    // let res = fun;
    let res = fun.bind(obj);
    nobjs += 1;
    objs[nobjs] = res;
    return nobjs;
}

const objcallarg = function(ptr) {
    tmpargs.push(objs[ptr]);
};

const objcall = function(ptr) {
    nobjs += 1;
    let n = nobjs;
    objs[n] = objs[ptr].apply(null, tmpargs);
    tmpargs.length = 0;
    return n;
};

const env = {
    putchar,
    alloc,
    allocf,
    allocn,
    allocs,
    objdup,
    objrm,
    loadjs,
    tmpadd,
    tmpdel,
    objsetn,
    objsetptr,
    objgetn,
    objgetptr,
    objgetval,
    objbind,
    objcall,
    objcallarg,
};

WebAssembly.instantiate(src, { env }).then(res => {
    tbl = res.instance.exports.__indirect_function_table;
    res.instance.exports._start();
});