const http = require('http'),
    httpProxy = require('http-proxy');

const host = 'localhost';
const backend_port = 45000;
const backend_api_url = '/api';
const backend_socket_url = '/phoenix/live_reload/socket';
const proxy_port = 45020;
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
    if (req.url.includes(backend_api_url)) {
        backendProxy.web(req, res);
    } else {
        frontendProxy.web(req, res);
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
