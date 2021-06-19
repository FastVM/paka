#!/usr/bin/env node
const fs = require('fs');
const filename = process.argv[2];
const src = fs.readFileSync(filename);

var stdout='';

const putchar = function(code) {
    if (code === 10) {
        console.log(stdout);
        stdout = '';
    }
    else
    {
        stdout += String.fromCharCode(code);
    }
    return 0;
};

let mem;
const fd_write = function(fd, iovs, iovsLen, nwritten) {
    var view = new DataView(mem.buffer);
    var written = 0;
    function getiovs(iovs, iovsLen) {
        var buffers = Array.from({ length: iovsLen }, function (_, i) {
            var ptr = iovs + i * 8;
            var buf = view.getUint32(ptr, !0);
            var bufLen = view.getUint32(ptr + 4, !0);

            return new Uint8Array(mem.buffer, buf, bufLen);
        });

        return buffers;
    }
    var buffers = getiovs(iovs, iovsLen);
    function writev(iov) {
        for (var b = 0; b < iov.byteLength; b++) {
            putchar(iov[b]);
        }
        written += b;
    }
    buffers.forEach(writev);
    view.setUint32(nwritten, written, !0);
    return 0;
};

WebAssembly.instantiate(src, {wasi_unstable: {fd_write}}).then(res => {
    mem = res.instance.exports.memory;
    res.instance.exports._start();
});