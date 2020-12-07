const fs = require("fs")
const { WASI } = require("@wasmer/wasi")
const nodeBindings = require("@wasmer/wasi/lib/bindings/node")
const readline = require('readline-sync');
const { Volume } = require("memfs");

const wasmFilePath = "./dext.wasm"

const vol = Volume.fromJSON({});

// Instantiate a new WASI Instance
let wasi = new WASI({
    args: [wasmFilePath],
    env: {
        "__floatsitf": () => { throw "NYI" },
        "__extenddftf2": () => { throw "NYI" },
        "__trunctfdf2": () => { throw "NYI" },
        "__floatunsitf": () => { throw "NYI" },
        "__multf3": () => { throw "NYI" },
        "__addtf3": () => { throw "NYI" },
        "__netf2": () => { throw "NYI" },
        "__eqtf2": () => { throw "NYI" },
        "__letf2": () => { throw "NYI" },
        "__divtf3": () => { throw "NYI" },
    },
    bindings: {
        ...(nodeBindings.default || nodeBindings),
        fs: fs,
    }
})

// Async function to run our Wasm module/instance
const startWasiTask =
    async pathToWasmFile => {
        // Fetch our Wasm File
        let wasmBytes = new Uint8Array(fs.readFileSync(pathToWasmFile)).buffer

        // Instantiate the WebAssembly file
        let wasmModule = await WebAssembly.compile(wasmBytes);
        let imports = wasi.getImports(wasmModule);
        // imports.wasi_unstable.clock_res_get = (a, b) => 0; 
        let instance = await WebAssembly.instantiate(wasmModule, {
            ...imports,
            env: {
                "dext_readln": () => {
                    let name = readline.question('in: ');
                    for (var i = 0; i < name.length; i++) {
                        instance.exports.dext_addchar(name.charCodeAt(i));
                    }
                },
                "__floatsitf": () => { throw "NYI" },
                "__extenddftf2": () => { throw "NYI" },
                "__trunctfdf2": () => { throw "NYI" },
                "__floatunsitf": () => { throw "NYI" },
                "__multf3": () => { throw "NYI" },
                "__addtf3": () => { throw "NYI" },
                "__netf2": () => { throw "NYI" },
                "__eqtf2": () => { throw "NYI" },
                "__letf2": () => { throw "NYI" },
                "__divtf3": () => { throw "NYI" },
            }
        });

        // Start the WASI instance
        wasi.start(instance);
        console.log(instance.exports.dext_pushstr);

        // let str = "io.print(100);";

        // for (var i = 0; i < str.length; i++) {
        //     instance.exports.dext_addchar(i);
        // }

        // instance.exports.dext_emplace();

        // instance.exports.dext_emplace();

        // instance.exports.dext_wasi_main();

        // console.log(instance.exports.run());
    }

// Everything starts here
startWasiTask(wasmFilePath)
