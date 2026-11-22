// Merender keluaran gate CI lokal menjadi gambar PNG bergaya terminal.
//
// Pemakaian (dari folder proyek Week 13):
//   node tool/ci/render.mjs
//
// Input : tool/ci/results/<nama>.txt
// Output: screenshots/<nama>.png
//
// Isi gambar berasal langsung dari berkas yang dihasilkan perintah Flutter,
// bukan teks yang ditulis ulang di dalam skrip ini. Tinggi gambar diukur dari
// ukuran dokumen sebenarnya lewat Chrome DevTools Protocol, sehingga tidak ada
// teks terpotong maupun ruang kosong berlebih.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { spawn } from 'node:child_process';

const OUT = path.resolve('screenshots');
const RESULTS = path.resolve('tool/ci/results');
const DEBUG_PORT = Number(process.env.CI_DEBUG_PORT ?? 9666);
const CHROME =
  process.env.CHROME_PATH ??
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';

const JOBS = [
  {
    input: '01-format.txt',
    output: 'ci-local-format.png',
    title: 'dart format --set-exit-if-changed .',
    accent: '#22c55e',
  },
  {
    input: '02-analyze.txt',
    output: 'ci-local-analyze.png',
    title: 'flutter analyze --fatal-infos',
    accent: '#38bdf8',
  },
  {
    input: '03-test.txt',
    output: 'ci-local-test.png',
    title: 'flutter test --coverage',
    accent: '#a78bfa',
    // Keluaran test memuat satu baris progres untuk setiap test, sehingga
    // berkasnya 97 baris. Untuk gambar, ambil awal dan akhir keluaran saja;
    // berkas mentahnya tetap utuh di tool/ci/results/03-test.txt.
    trim: { head: 6, tail: 10 },
  },
  {
    input: '04-coverage.txt',
    output: 'ci-local-coverage.png',
    title: 'ringkasan cakupan (coverage/lcov.info)',
    accent: '#f59e0b',
  },
];

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const escapeHtml = (text) =>
  text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

/// Mengambil beberapa baris awal dan akhir keluaran, lalu menandai bagian yang
/// dihilangkan. Dipakai agar gambar tetap terbaca tanpa memotong kesimpulan
/// hasil di bagian bawah.
function trimBody(text, { head, tail }) {
  const lines = text.split(/\r?\n/);
  if (lines.length <= head + tail + 1) return text;

  const omitted = lines.length - head - tail;
  return [
    ...lines.slice(0, head),
    `... (${omitted} baris keluaran dihilangkan, berkas lengkap ada di tool/ci/results/) ...`,
    ...lines.slice(-tail),
  ].join('\n');
}

function buildHtml(title, body, accent) {
  return `<!doctype html><html lang="id"><head><meta charset="utf-8">
<style>
  * { box-sizing: border-box; }
  body {
    margin: 0;
    padding: 28px;
    background: #0b1120;
    font-family: "Cascadia Mono", Consolas, "Courier New", monospace;
  }
  .card {
    background: #0f172a;
    border: 1px solid #1e293b;
    border-radius: 14px;
    overflow: hidden;
  }
  .bar {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 12px 18px;
    background: #111c33;
    border-bottom: 1px solid #1e293b;
  }
  .dot { width: 11px; height: 11px; border-radius: 50%; }
  .title {
    color: #e2e8f0;
    font-size: 15px;
    font-weight: 600;
    margin-left: 6px;
    letter-spacing: .2px;
  }
  .tag {
    margin-left: auto;
    font-size: 11px;
    color: #0b1120;
    background: ${accent};
    padding: 3px 9px;
    border-radius: 999px;
    font-weight: 700;
    letter-spacing: .5px;
  }
  pre {
    margin: 0;
    padding: 20px 22px;
    color: #cbd5e1;
    font-size: 13.5px;
    line-height: 1.62;
    white-space: pre-wrap;
    word-break: break-word;
  }
</style></head><body>
<div class="card" id="card">
  <div class="bar">
    <span class="dot" style="background:#ef4444"></span>
    <span class="dot" style="background:#f59e0b"></span>
    <span class="dot" style="background:#22c55e"></span>
    <span class="title">${escapeHtml(title)}</span>
    <span class="tag">BUKTI LOKAL</span>
  </div>
  <pre>${escapeHtml(body)}</pre>
</div>
</body></html>`;
}

const userDataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'week13-ci-'));
fs.mkdirSync(OUT, { recursive: true });

const chrome = spawn(
  CHROME,
  [
    '--headless=new',
    `--remote-debugging-port=${DEBUG_PORT}`,
    `--user-data-dir=${userDataDir}`,
    '--no-first-run',
    '--hide-scrollbars',
    '--window-size=1180,900',
    'about:blank',
  ],
  { stdio: 'ignore' },
);

async function waitForEndpoint(url, timeoutMs = 30000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const res = await fetch(url);
      if (res.ok) return await res.json();
    } catch {
      /* belum siap */
    }
    await sleep(200);
  }
  throw new Error(`Endpoint tidak siap: ${url}`);
}

let ws;
try {
  await waitForEndpoint(`http://127.0.0.1:${DEBUG_PORT}/json/version`);
  const target = await (
    await fetch(`http://127.0.0.1:${DEBUG_PORT}/json/new?about:blank`, {
      method: 'PUT',
    })
  ).json();

  ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    ws.onopen = resolve;
    ws.onerror = reject;
  });

  let id = 0;
  const pending = new Map();
  ws.onmessage = (event) => {
    const msg = JSON.parse(event.data);
    if (msg.id && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      if (msg.error) reject(new Error(JSON.stringify(msg.error)));
      else resolve(msg.result);
    }
  };
  const send = (method, params = {}) => {
    const msgId = ++id;
    ws.send(JSON.stringify({ id: msgId, method, params }));
    return new Promise((resolve, reject) => {
      pending.set(msgId, { resolve, reject });
      setTimeout(
        () => pending.has(msgId) && reject(new Error(`timeout ${method}`)),
        60000,
      );
    });
  };

  await send('Page.enable');
  await send('Emulation.setDeviceMetricsOverride', {
    width: 1180,
    height: 900,
    deviceScaleFactor: 2,
    mobile: false,
  });

  for (const job of JOBS) {
    const inputPath = path.join(RESULTS, job.input);
    if (!fs.existsSync(inputPath)) {
      console.warn(`Lewati ${job.input}: berkas tidak ditemukan`);
      continue;
    }

    const raw = fs.readFileSync(inputPath, 'utf8').trimEnd();
    const body = job.trim ? trimBody(raw, job.trim) : raw;
    const html = buildHtml(job.title, body, job.accent);
    const dataUrl =
      'data:text/html;base64,' + Buffer.from(html, 'utf8').toString('base64');

    await send('Page.navigate', { url: dataUrl });
    await sleep(500);

    // Ukur tinggi kartu sebenarnya, lalu ambil screenshot tepat setinggi itu.
    const measured = await send('Runtime.evaluate', {
      expression:
        "(() => { const r = document.getElementById('card').getBoundingClientRect();" +
        " return JSON.stringify({ h: Math.ceil(r.height + 56), w: 1180 }); })()",
      returnByValue: true,
    });
    const size = JSON.parse(measured.result.value);

    const { data } = await send('Page.captureScreenshot', {
      format: 'png',
      captureBeyondViewport: true,
      clip: { x: 0, y: 0, width: size.w, height: size.h, scale: 1 },
    });

    const outPath = path.join(OUT, job.output);
    fs.writeFileSync(outPath, Buffer.from(data, 'base64'));
    console.log(
      `render -> screenshots/${job.output} (${size.w}x${size.h} CSS px)`,
    );
  }
} finally {
  ws?.close();
  chrome.kill();
  await sleep(400);
  fs.rmSync(userDataDir, { recursive: true, force: true });
}
