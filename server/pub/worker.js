const runFile = function(stream, putchar) {
    var stdout='';

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

    return WebAssembly.instantiateStreaming(stream, {wasi_unstable: {fd_write}}).then(res => {
        mem = res.instance.exports.memory;
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
