let worker;
let lastput;

function compile(src, putchar) {
    if (worker !== undefined) {
        putchar('__TERM__');
        worker.terminate();
    }
    worker = new Worker('worker.js');
    worker.postMessage(src);
    worker.onmessage = function(e) {
        putchar(e.data);
    };
    lastput = putchar;
}