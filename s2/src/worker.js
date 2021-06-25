const runFile = function(stream, putchar) {
    let ctx = globalThis;
    let objs = new Map();
    let nobjs = 0;
    let tmpstr = '';
    let tmpargs = [];

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

    return WebAssembly.instantiateStreaming(stream, { env }).then(res => {
        putchar('__BEGIN__');
        res.instance.exports._start();
        putchar('__END__');
    });
}

function compile(src, putchar) {
    const stream = fetch('/api/wasm', {
        method: 'POST',
        mode: 'cors',
        cache: 'no-cache',
        headers: {
            'Content-Type': 'text/plain',
        },
        redirect: 'follow',
        body: src,
    })
    runFile(stream, putchar);
}

onmessage = function(e) {
    compile(e.data, function(c) {
        postMessage(c);
    });
};