// Server statis + generator gambar deterministik untuk harness profiling.
//
// - Menyajikan hasil `flutter build web` pada "/"
// - Menyajikan PNG sintetis pada "/img/<w>x<h>/<id>.png"
//
// Gambar dibuat lokal agar waktu decode/transfer identik pada setiap run
// (tidak terpengaruh latensi internet), sehingga perbandingan before/after
// hanya dipengaruhi oleh perubahan kode aplikasi.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

const ROOT = path.resolve(process.argv[2] ?? 'build/perf_web');
const PORT = Number(process.env.PERF_PORT ?? 8777);

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.bin': 'application/octet-stream',
  '.symbols': 'application/octet-stream',
};

const CRC_TABLE = (() => {
  const table = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[n] = c;
  }
  return table;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) {
    c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  }
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

const imageCache = new Map();

function makePng(width, height, seed) {
  const key = `${width}x${height}/${seed}`;
  const cached = imageCache.get(key);
  if (cached) return cached;

  const stride = width * 3 + 1;
  const raw = Buffer.alloc(stride * height);
  const r0 = (seed * 37) % 200;
  const g0 = (seed * 91) % 180;
  const b0 = (seed * 53) % 160;

  for (let y = 0; y < height; y++) {
    raw[y * stride] = 0; // filter: none
    for (let x = 0; x < width; x++) {
      const stripe = Math.sin((x + y + seed * 7) / 24) * 26;
      const glow = Math.round((x / width) * 40);
      const o = y * stride + 1 + x * 3;
      raw[o] = Math.max(0, Math.min(255, r0 + glow + stripe));
      raw[o + 1] = Math.max(0, Math.min(255, g0 + stripe * 0.7));
      raw[o + 2] = Math.max(0, Math.min(255, b0 + 60 - glow));
    }
  }

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 2; // truecolor
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;

  const png = Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 6 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);

  imageCache.set(key, png);
  return png;
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://127.0.0.1:${PORT}`);

  const imageMatch = url.pathname.match(/^\/img\/(\d+)x(\d+)\/(\d+)\.png$/);
  if (imageMatch) {
    const [, w, h, id] = imageMatch;
    const png = makePng(Number(w), Number(h), Number(id));
    res.writeHead(200, {
      'Content-Type': 'image/png',
      'Content-Length': png.length,
      'Cache-Control': 'public, max-age=31536000, immutable',
      'Access-Control-Allow-Origin': '*',
    });
    res.end(png);
    return;
  }

  let filePath = path.join(ROOT, decodeURIComponent(url.pathname));
  if (!filePath.startsWith(ROOT)) {
    res.writeHead(403).end('forbidden');
    return;
  }
  if (url.pathname === '/' || !path.extname(filePath)) {
    filePath = path.join(ROOT, 'index.html');
  }
  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    res.writeHead(404).end('not found');
    return;
  }

  const ext = path.extname(filePath).toLowerCase();
  const body = fs.readFileSync(filePath);
  res.writeHead(200, {
    'Content-Type': MIME[ext] ?? 'application/octet-stream',
    'Content-Length': body.length,
    'Cache-Control': ext === '.html' ? 'no-store' : 'no-cache',
  });
  res.end(body);
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`perf-server listening on http://127.0.0.1:${PORT} (root: ${ROOT})`);
});
