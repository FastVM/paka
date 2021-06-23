import "regenerator-runtime/runtime"
import * as monaco from 'monaco-editor';
import './style.css';

let worker;

function compile(src, putchar) {
    if (worker !== undefined) {
        putchar('__TERM__');
        worker.terminate();
    }
    worker = new Worker(new URL('./worker.js',
        import.meta.url));
    worker.postMessage(src);
    worker.onmessage = function(e) {
        putchar(e.data);
    };
}

const pakaLang = function() {
    return {
        keywords: [
            "if", "else", "def", "lambda",
            "import", "true", "false", "nil", "table",
            "while", "static", "return"
        ],

        typeKeywords: [
            'Nil', 'Int', 'Float', 'Text',
        ],

        operators: [
            ["::"],
            ["->"],
            ["+=", "~=", "*=", "/=", "%=", "-=", "="],
            ["|>", "<|"],
            ["or", "and"],
            ["<=", ">=", "<", ">", "!=", "=="],
            ["+", "-"],
            ["*", "/", "%"]
        ].flat(),

        // we include these common regular expressions
        symbols: /[=><!~?:&|+\-*\/\^%]+/,

        // C# style strings
        escapes: /\\(?:[abfnrtv\\"]|x[0-9A-Fa-f]{1,4}|u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8})/,

        // The main tokenizer for our languages
        tokenizer: {
            root: [
                // identifiers and keywords
                [/[a-z_$][\w$]*/, {
                    cases: {
                        '@typeKeywords': 'keyword',
                        '@keywords': 'keyword',
                        '@default': 'identifier'
                    }
                }],
                [/[A-Z][\w\$]*/, 'type.identifier'], // to show class names nicely

                // whitespace
                { include: '@whitespace' },

                // delimiters and operators
                [/[{}()\[\]]/, '@brackets'],
                [/[<>](?!@symbols)/, '@brackets'],
                [/@symbols/, {
                    cases: {
                        '@operators': 'operator',
                        '@default': ''
                    }
                }],

                // numbers
                [/\d*\.\d+([eE][\-+]?\d+)?/, 'number.float'],
                [/0[xX][0-9a-fA-F]+/, 'number.hex'],
                [/\d+/, 'number'],

                // delimiter: after number because of .\d floats
                [/[;,.]/, 'delimiter'],

                // strings
                [/"([^"\\]|\\.)*$/, 'string.invalid'], // non-teminated string
                [/"/, { token: 'string.quote', bracket: '@open', next: '@string' }],

                // characters
                [/'[^\\']'/, 'string'],
                [/(')(@escapes)(')/, ['string', 'string.escape', 'string']],
                [/'/, 'string.invalid']
            ],

            comment: [
                [/##.*/, 'comment']
            ],

            string: [
                [/[^\\"]+/, 'string'],
                [/@escapes/, 'string.escape'],
                [/\\./, 'string.escape.invalid'],
                [/"/, { token: 'string.quote', bracket: '@close', next: '@pop' }]
            ],

            whitespace: [
                [/[ \t\r\n]+/, 'white'],
                [/##*/, 'comment', '@comment'],
                [/##.*$/, 'comment'],
            ],
        },
    };

}
const rereq = async function(src, cb) {
    let res = await fetch('/api/info', {
        method: 'POST',
        mode: 'cors',
        cache: 'no-cache',
        headers: {
            'Content-Type': 'text/plain',
        },
        redirect: 'follow',
        body: src,
    });
    return res.json();
};

let ty2s = function(obj) {
    if (Array.isArray(obj)) {
        obj = {
            type: 'tuple',
            elems: obj,
        };
    }
    switch (obj.type) {
        case 'nil':
            return 'Nil';
        case 'logical':
            return 'Logical';
        case 'int':
            return 'Int';
        case 'float':
            return 'Float';
        case 'text':
            return 'Text';
        case 'higher':
            return `type(${ty2s(obj.of)})`;
        case 'lambda':
            let argl = obj.args.map(ty2s);
            return `(${argl}) -> ${ty2s(obj.return)}`;
        case 'function':
            let argf = obj.args.map(ty2s);
            return `(${argf}) -> ${ty2s(obj.return)}`;
        case 'tuple':
            let uret = '(';
            for (let i = 0; i < obj.elems.length; i++) {
                if (i != 0) {
                    uret += ', ';
                }
                uret += ty2s(obj.elems[i]);
            }
            uret += ')';
            return uret;
        case 'generic':
            let opts = new Set();
            for (let i = 0; i < obj.rets.length; i++) {
                let retn = obj.rets[i];
                let casen = obj.cases[i];
                let me = '' + ty2s(casen) + ': ' + ty2s(retn);
                opts.add(me);
            }
            return `generic {${Array.from(opts)}}`;
        case 'rec':
            return '...';
    }
    throw obj;
};

const scorePosition = function(line, col) {
    return line * 65536 + col;
};

document.addEventListener('DOMContentLoaded', function() {
    const editor = monaco.editor.create(document.getElementById('paka-main-input'), {
        value: '',
        language: 'paka',
        theme: 'vs-dark',
        automaticLayout: true,
    });

    monaco.languages.register({ id: 'paka' });
    monaco.languages.setMonarchTokensProvider('paka', pakaLang());
    monaco.languages.registerHoverProvider('paka', {
        provideHover: async function(model, position) {
            let middle = scorePosition(position.lineNumber, position.column);
            let res = await rereq(model.getValue());
            let found = '???';
            let best = null;
            for (let pair of res.pairs) {
                let first = pair.span.first;
                let last = pair.span.last;
                let low = scorePosition(first.line, first.col);
                let high = scorePosition(last.line, last.col);
                if (low <= middle && middle <= high) {
                    if (best == null || high - low < best) {
                        best = high - low;
                        found = ty2s(pair.type);
                    }
                }
            }
            return {
                contents: [
                    { value: '**TYPE**' },
                    { value: found || '???' },
                ]
            }
        },
    });

    const result = monaco.editor.create(document.getElementById('paka-main-output'), {
        value: '',
        language: 'txt',
        theme: 'vs-dark',
        modal: true,
        readOnly: true,
        automaticLayout: true,
    });

    const run = function() {
        let src = editor.getModel().getValue();
        let matches = src.match(/##\s*pragma\s+bench/g);
        let runBench = matches !== null;
        let state = Object.freeze({
            vars: {
                stdout: '',
            },
            format: function() {
                let res = state.vars.stdout;
                if (runBench) {
                    if (state.vars.endTime !== undefined) {
                        let real = state.vars.endTime - state.vars.initTime;
                        let user = state.vars.endTime - state.vars.beginTime;
                        let wait = state.vars.beginTime - state.vars.initTime;
                        res += '\n';
                        if (real >= 0 && user >= 0 && wait >= 0) {
                            res += 'real: ' + String(real) + 'ms\n';
                            res += 'user: ' + String(user) + 'ms\n';
                            res += 'wait: ' + String(wait) + 'ms\n';
                        }
                    }
                }
                return res;
            }
        });
        const putchar = function(chr) {
            if (typeof chr === 'number') {
                if (chr === 0) {
                    state.vars.stdout = '';
                } else {
                    state.vars.stdout += String.fromCharCode(chr);
                }
            } else {
                switch (chr) {
                    default: state.vars.stdout += chr;
                    break;
                    case '__BEGIN__':
                            state.vars.beginTime = new Date();
                        break;
                    case '__END__':
                            state.vars.endTime = new Date();
                        state.vars.status = 'SIGTERM';
                        break;
                    case '__TERM__':
                            state.vars.endTime = new Date();
                        state.vars.status = 'SIGKILL';
                        break;
                }
            }
            result.getModel().setValue(state.format());
        }
        compile(src, putchar);
        state.vars.initTime = new Date();
        state.vars.status = '';
        result.getModel().setValue(state.format());
    };

    editor.createContextKey('myCondition1')
    editor.addAction({
        id: 'paka-code-run',
        label: 'Paka: Compile And Run',
        keybindings: [
            monaco.KeyMod.CtrlCmd | monaco.KeyCode.KEY_S
        ],
        run: run,
    });

    result.addAction({
        id: 'save-stdout',
        label: 'Save',
        keybindings: [monaco.KeyMod.CtrlCmd | monaco.KeyCode.KEY_S],
        run: function() {
            const text = result.getModel().getValue();
            const element = document.createElement('a');
            element.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(text));
            element.setAttribute('download', 'stdout.txt');
            element.style.display = 'none';
            document.body.appendChild(element);
            element.click();
            document.body.removeChild(element);
        },
    });

    editor.onKeyDown(function(event) {
        if (event.ctrlKey && event.keyCode === monaco.KeyCode.KEY_S) {
            event.preventDefault();
        }
    });

    editor.onKeyUp(function(event) {
        if (event.ctrlKey && event.keyCode === monaco.KeyCode.KEY_S) {
            event.preventDefault();
        }
    });
});