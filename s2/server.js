const express = require('express');
const body = require('body-parser')
const fs = require('fs-extra');
const uuid = require('uuid');
var https = require('https');
const proc = require('child_process');

const app = express();
app.use(express.static('dist'));
app.use(body.text({
    type: 'text/plain',
    extended: true,
}));

const runCompiler = function(src, method, callback) {
    const workdir = __dirname + '/wasm/' + uuid.v4();
    fs.copy(__dirname + '/base', workdir)
        .then(function() {
            fs.writeFile(workdir + '/input', src, function() {
                try {
                    proc.execFile(__dirname + '/bin/purr', ['--debug', '--' + method + '=' + workdir + '/input', '--wasm=wasmer'], {
                        cwd: workdir,
                        env: { 'PATH': __dirname + '/bin' },
                        timeout: 2000,
                    }, (err, stdout, stderr) => {
                        callback(err, stdout, stderr, workdir);
                    });
                } catch (e) {
                    console.log(e);
                }
            });
        })
        .catch(e => console.log(e));
};

app.post('/api/wasm', (req, res) => {
    const thens = function(err, stdout, stderr, workdir) {
        console.log(stdout, stderr);
        if (err != null) {
            res.status(400);
            try {
                throw err;
            } catch (e) {
                console.log(e);
            }
        } else {
            res.contentType('application/wasm');
            res.sendFile(workdir + '/bin/out', function() {});
            res.status(200);
        }
    }
    runCompiler(req.body, 'compile', thens);
});

app.post('/api/info', (req, res) => {
    const thens = function(err, stdout, stderr, workdir) {
        console.log('info req');
        if (err != null) {
            try {
                throw err;
            } catch (e) {
                console.log(e);
            }
            res.status(400);
        } else {
            res.contentType('application/json');
            res.sendFile(workdir + '/bin/editor.json', function() {});
            res.status(200);
        }
    }
    runCompiler(req.body, 'validate', thens);
});

var server = https.createServer({}, app);

// app.listen(80, () => {
//     console.log('http started');
// })

// server.listen(443, () => {
//     console.log('https started');
// })

server.listen(8000, () => {
    console.log('dev started');
})