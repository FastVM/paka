#!/usr/bin/env node

const fs = require('fs');
const filename = process.argv[2];
const src = fs.readFileSync(filename);

let ctx = globalThis;
let objs = new Array(1);
let frees = [];
let stdout = '';
let tbl;
let mbuf;

ctx.objs = objs;

ctx.require = require;

ctx.purr_array_cons = function() {
    return Array.from(arguments);
};

const push = function(v) {
    if (frees.length) {
        let ret = frees.shift();
        objs[ret] = v;
        return ret;
    } else {
        let ret = objs.length;
        objs.push(v);
        return ret;
    }
};

const loadstr = function(mlen, mptr) {
    let cached = cache[mptr];
    if (cached) {
        return cached;
    } else {
        let ret = '';
        for (let i = 0; i < mlen; i += 1) {
            ret += String.fromCharCode(mbuf[mptr + i]);
        }
        cache[mptr] = ret;
        return ret;
    }
};

let free_symbol = Symbol("free");

const objrm = function(ptr) {
    frees.push(ptr);
    objs[ptr] = free_symbol;
};

const alloc = function() {
    return push(new Map());
};

const allocn = function(n) {
    return push(n);
};

const allocf = function(f) {
    let fun = tbl.get(f);
    return push(function() {
        if (arguments.length != fun.length) {
            throw new Error(`argc errro: given ${arguments.length}, expected ${fun.length}`)
        }
        let args = Array.prototype.map.call(arguments, function(a) {
            return push(a);
        });
        let res = fun.apply(null, args);
        return objs[res];
    });
};

const allocs = function(mlen, mptr) {
    return push(loadstr(mlen, mptr));
};

const objdup = function(ptr) {
    return push(objs[ptr]);
};

const loadjs = function(mlen, mptr) {
    return push(ctx[loadstr(mlen, mptr)]);
};

let cache = new Map();

const objsetptr = function(ptr, val, mlen, mptr) {
    objs[ptr][loadstr(mlen, mptr)] = val;
};

const objsetn = function(ptr, val, n) {
    objs[ptr][n] = objs[val];
}

const objgetptr = function(ptr, mlen, mptr) {
    return push(objs[ptr][loadstr(mlen, mptr)]);
};

const objgetn = function(ptr, n) {
    return push(objs[ptr][n]);
};

const objgetval = function(ptr) {
    return objs[ptr];
}

const objbind = function(ptr, mlen, mptr) {
    let obj = objs[ptr];
    let fun = obj[loadstr(mlen, mptr)];
    let res = fun.bind(obj);
    return push(res);
}

const objcalln = function(ptr, ...rest) {
    let res = objs[ptr].apply(null, rest.map(x => objs[x]));
    return push(res);
};

const env = {
    objrm,
    alloc,
    allocf,
    allocn,
    allocs,
    objdup,
    loadjs,
    objsetn,
    objsetptr,
    objgetn,
    objgetptr,
    objgetval,
    objbind,
};

for (let i = 0; i < 256; i += 1) {
    env[`objcall${i}`] = objcalln;
}

WebAssembly.instantiate(src, { env }).then(res => {
    tbl = res.instance.exports.__indirect_function_table;
    mbuf = new Uint8Array(res.instance.exports.memory.buffer);
    res.instance.exports._start();
    console.log(`used ${objs.length} memory slots`);
})