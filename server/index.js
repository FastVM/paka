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
        .then(function() {
            fs.writeFile(workdir + '/input', req.body, function() {
            proc.execFile(workdir + '/bin/purr', ['--compile=' + workdir + '/input', '--wasm=wasmer'], {
                cwd: workdir,
                env: {'PATH': workdir + '/bin'},
                timeout: 2000,
            }, function(err, stdout, stderr) {
                console.log(stdout, stderr);
                if (err != null) {
                    res.status(400);
                    try {
                        throw err;
                    }
                    catch (e) {
                        console.log(e);
                    }
                    fs.rm(workdir, {recursive: true});
                    res.end();
                    return;
                }
                res.contentType('application/wasm');
                res.sendFile(workdir + '/bin/out', function() {
                    fs.rm(workdir, {recursive: true});
                });
                res.status(200);
                res.end();
            });
        });
    });
})

app.listen(8000, () => {
    console.log('app started');
})