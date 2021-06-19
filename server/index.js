const express = require('express');
const body = require('body-parser')
const fs = require('fs-extra');
const uuid = require('uuid');
const proc = require('child_process');

const app = express();
app.use(express.static('pub'));
app.use(body.text({
    type: 'text/plain',
    extended: true,
}));

app.post('/api/wasm', (req, res) => {
    const workdir = __dirname + '/wasm/' + uuid.v4();
    fs.copy(__dirname + '/base', workdir)
        .then(done => {
            fs.writeFile(workdir + '/input', req.body, function() {
            proc.execFile(workdir + '/bin/purr', ['--compile=' + workdir + '/input', '--wasm=wasmer'], {
                cwd: undefined,
                env: {},
                timeout: 500,
            }, function(proc) {
                res.sendFile(workdir + '/bin/out');
            });
        });
    });
})

app.listen(8000, () => {
    console.log('app started');
})