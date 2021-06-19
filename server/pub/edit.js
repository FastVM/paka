require.config({ paths: { 'vs': '/vs' } });

let updateFile = function () { };

var loadFile = function (select) {
    fetch('/paka/' + select.value)
        .then(function (res) {
            return res.text();
        })
        .then(function (text) {
            updateFile(text);
        });
}

const pakaLang = function () {
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
            ["::"], ["->"],
            ["+=", "~=", "*=", "/=", "%=", "-=", "="], ["|>", "<|"],
            ["or", "and"], ["<=", ">=", "<", ">", "!=", "=="], ["+", "-"],
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
                [/[A-Z][\w\$]*/, 'type.identifier'],  // to show class names nicely

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

                // @ annotations.
                // As an example, we emit a debugging log message on these tokens.
                // Note: message are supressed during the first load -- change some lines to see them.
                [/@\s*[a-zA-Z_\$][\w\$]*/, { token: 'annotation', log: 'annotation token: $0' }],

                // numbers
                [/\d*\.\d+([eE][\-+]?\d+)?/, 'number.float'],
                [/0[xX][0-9a-fA-F]+/, 'number.hex'],
                [/\d+/, 'number'],

                // delimiter: after number because of .\d floats
                [/[;,.]/, 'delimiter'],

                // strings
                [/"([^"\\]|\\.)*$/, 'string.invalid'],  // non-teminated string
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
                [/\/\*/, 'comment', '@comment'],
                [/\/\/.*$/, 'comment'],
            ],
        },
    };

}

require(['vs/editor/editor.main'], function () {
    monaco.languages.register({ id: 'paka' });
    monaco.languages.setMonarchTokensProvider('paka', pakaLang());

    const editor = monaco.editor.create(document.getElementById('paka-main-input'), {
        value: '',
        language: 'paka',
        theme: 'vs-dark',
        automaticLayout: true,
    });

    const result = monaco.editor.create(document.getElementById('paka-main-output'), {
        value: '',
        language: 'txt',
        theme: 'vs-dark',
        modal: true,
        readOnly: true,
        automaticLayout: true,
    })

    const run = function () {
        let src = editor.getModel().getValue();
        let matches = src.match(/##\s*pragma\s+bench/g);
        let runBench = matches !== null;
        let state = Object.freeze({
            vars: {
                stdout: '',
            },
            format: function () {
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
        const putchar = function (chr) {
            if (typeof chr === 'number') {
                if (chr === 0) {
                    state.vars.stdout = '';
                } else {
                    state.vars.stdout += String.fromCharCode(chr);
                }
            } else {
                switch (chr) {
                    default:
                        state.vars.stdout += chr;
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

    updateFile = function (text) {
        editor.getModel().setValue(text);
        run();
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
        run: function () {
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

    editor.onKeyDown(function (event) {
        if (event.ctrlKey && event.keyCode === monaco.KeyCode.KEY_S) {
            event.preventDefault();
        }
    });

    editor.onKeyUp(function (event) {
        if (event.ctrlKey && event.keyCode === monaco.KeyCode.KEY_S) {
            event.preventDefault();
        }
    });
});
