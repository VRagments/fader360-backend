const http = require('http'),
    httpProxy = require('http-proxy');

const host = '127.0.0.1';
const proxy_port = 45020;

/**
 * Currently, it seems we are launching backend websocket requests from '/phoenix/live_reload/socket/websocket?[...]'
 * and from '/live/websocket?[...]', so this should suffice for now(?)
 * Nb:
 * Webpack on frontend also uses websocket, call is to 'ws://localhost:45010/ws' so should work
 */
const backend_socket_url = '/websocket';
const backend_port = 45000;

const frontend_url = '/editor';
const frontend_port = 45010;

const backendProxy = httpProxy.createProxyServer({
    target: {
        host,
        port: backend_port,
    },
});

const frontendProxy = httpProxy.createProxyServer({
    target: {
        host,
        port: frontend_port,
    },
});

const server = http.createServer((req, res) => {
    if (req.url.includes(frontend_url)) {
        frontendProxy.web(req, res);
    } else {
        backendProxy.web(req, res);
    }
});

/** Listen for Websocket requests */
server.on('upgrade', (req, socket, head) => {
    if (req.url.includes(backend_socket_url)) {
        backendProxy.ws(req, socket, head);
    } else {
        frontendProxy.ws(req, socket, head);
    }
});

server.listen(proxy_port);
// eslint-disable-next-line no-console
console.log(`Proxy server running on ${host}:${proxy_port}`);

backendProxy.on('error', (err) => {
    // eslint-disable-next-line no-console
    console.error('backendProxy error!', err);
});

frontendProxy.on('error', (err) => {
    // eslint-disable-next-line no-console
    console.error('frontendProxy error!', err);
});
