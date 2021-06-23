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

const allocs = function() {
    nobjs += 1;
    objs[nobjs] = tmpstr;
    return nobjs;
};

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

const objgetptr = function(ptr) {
    nobjs += 1;
    objs[nobjs] = objs[ptr][tmpstr];
    return nobjs;
};

const objgetval = function(ptr) {
    return objs[ptr];
}

const objcallarg = function(ptr) {
    tmpargs.push(objs[ptr]);
};

const objcall = function(ptr) {
    nobjs += 1;
    objs[nobjs] = objs[ptr](...tmpargs);
    tmpargs.length = 0;
    return nobjs;
};

const env = {
    putchar,
    alloc,
    allocn,
    allocs,
    loadjs,
    tmpadd,
    tmpdel,
    objsetptr,
    objgetptr,
    objgetval,
    objcall,
    objcallarg,
};

WebAssembly.instantiate(src, { env }).then(res => {
    res.instance.exports._start();
});