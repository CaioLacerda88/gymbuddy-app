/**
 * Custom static file server for Playwright E2E tests.
 *
 * Uses only built-in Node.js modules (http, fs, path) — zero external
 * dependencies. Replaces `npx http-server` which crashed under concurrent
 * load from 147 tests with 2 Playwright workers.
 *
 * Usage: node static-server.cjs [root-dir] [port]
 *   root-dir  Directory to serve (default: '.')
 *   port      Port to listen on (default: 4200)
 *
 * Features:
 * - Serves dotfiles (critical for flutter_dotenv loading .env)
 * - SPA fallback to index.html (Flutter hash routing)
 * - Streaming responses via fs.createReadStream (backpressure-safe)
 * - No caching headers
 */

'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(process.argv[2] || '.');
const PORT = parseInt(process.argv[3], 10) || 4200;

const MIME_TYPES = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.css': 'text/css',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.ico': 'image/x-icon',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.svg': 'image/svg+xml',
  '.bin': 'application/octet-stream',
  '.txt': 'text/plain',
  '.map': 'application/json',
};

/**
 * Resolve the requested URL path to a filesystem path, returning null if
 * no file exists. Handles directory requests by looking for index.html
 * inside the directory.
 */
function resolveFilePath(urlPath) {
  // Decode percent-encoded characters and strip query string / hash
  const decoded = decodeURIComponent(urlPath.split('?')[0].split('#')[0]);
  const filePath = path.join(ROOT, decoded);

  // Security: prevent directory traversal outside ROOT
  if (!filePath.startsWith(ROOT)) {
    return null;
  }

  try {
    const stat = fs.statSync(filePath);
    if (stat.isFile()) {
      return filePath;
    }
    if (stat.isDirectory()) {
      // Try index.html inside the directory
      const indexPath = path.join(filePath, 'index.html');
      if (fs.existsSync(indexPath) && fs.statSync(indexPath).isFile()) {
        return indexPath;
      }
    }
  } catch {
    // File does not exist — caller will handle SPA fallback
  }

  return null;
}

const server = http.createServer((req, res) => {
  const urlPath = req.url || '/';

  // Try to resolve the requested path to a real file
  let filePath = resolveFilePath(urlPath);

  // SPA fallback: if no file found, serve index.html from root
  if (!filePath) {
    const indexPath = path.join(ROOT, 'index.html');
    try {
      if (fs.statSync(indexPath).isFile()) {
        filePath = indexPath;
      }
    } catch {
      // index.html does not exist either — genuine 404
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Not Found');
      return;
    }
  }

  const ext = path.extname(filePath).toLowerCase();
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';

  res.writeHead(200, {
    'Content-Type': contentType,
    'Cache-Control': 'no-cache, no-store',
  });

  const stream = fs.createReadStream(filePath);
  stream.pipe(res);

  stream.on('error', (err) => {
    // If headers already sent, we can only destroy the response
    if (res.headersSent) {
      res.destroy();
      return;
    }
    res.writeHead(500, { 'Content-Type': 'text/plain' });
    res.end('Internal Server Error');
  });
});

server.listen(PORT, () => {
  console.log(`Listening on http://localhost:${PORT}`);
});
