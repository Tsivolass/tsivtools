// Sends WaveShield API requests through Node.js for server/security.lua.
// FXServer's PerformHttpRequest blocks every .xyz domain (citizenfx/fivem#4203),
// which includes api.waveshield.xyz, so security.lua falls back to this export.
const http = require('http');
const https = require('https');

exports('waveHttpsRequest', (url, method, payload, headers, timeoutMs, callback) => {
    let finished = false;
    const finish = (status, body, error) => {
        if (finished) return;
        finished = true;
        callback(status, body, error);
    };

    try {
        const target = new URL(url);
        const client = target.protocol === 'http:' ? http : https;
        const body = typeof payload === 'string' ? payload : '';
        const requestHeaders = Object.assign({}, headers || {});
        requestHeaders['Content-Length'] = Buffer.byteLength(body);

        const request = client.request(target, {
            method: method || 'GET',
            headers: requestHeaders,
            timeout: Number(timeoutMs) || 10000,
        }, (response) => {
            const chunks = [];
            response.on('data', (chunk) => chunks.push(chunk));
            response.on('end', () => finish(response.statusCode || 0, Buffer.concat(chunks).toString('utf8'), null));
            response.on('error', (err) => finish(0, null, String((err && err.message) || err)));
        });
        request.on('timeout', () => request.destroy(new Error('request timed out')));
        request.on('error', (err) => finish(0, null, String((err && err.message) || err)));
        request.end(body);
    } catch (err) {
        finish(0, null, String((err && err.message) || err));
    }
});
