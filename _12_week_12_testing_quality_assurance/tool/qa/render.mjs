// Merender keluaran alat (flutter analyze, flutter test, coverage, integration
// test) menjadi gambar PNG bergaya terminal.
//
// Pemakaian:
//   node tool/qa/render.mjs
//
// Input : tool/qa/results/<nama>.txt
// Output: screenshots/<nama>.png
//
// Gambar dibuat dari berkas hasil yang benar benar dihasilkan perintah Flutter,
// bukan teks yang ditulis ulang di dalam skrip ini. Tinggi gambar diambil dari
// ukuran dokumen sebenarnya melalui Chrome DevTools Protocol, sehingga tidak
// ada teks terpotong maupun ruang kosong berlebih.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { spawn } from 'node:child_process';

const OUT = path.resolve('screenshots');
const RESULTS = path.resolve('tool/qa/results');
const DEBUG_PORT = Number(process.env.QA_DEBUG_PORT ?? 9555);
const CHROME =
  process.env.CHROME_PATH ??
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';

const JOBS = [
  {
    input: 'analyze.txt',
    output: 'qa-analyze.png',
    title: 'flutter analyze',
    accent: '#22c55e',
  },
  {
    input: 'test.txt',
    output: 'qa-flutter-test.png',
    title: 'flutter test',
    accent: '#38bdf8',
  },
  {
    input: 'coverage.txt',
    output: 'qa-coverage.png',
    title: 'flutter test --coverage',
    accent: '#a78bfa',
  },
  {
    input: 'integration_test.txt',
    output: 'qa-integration-test.png',
    title: 'flutter test integration_test/app_test.dart -d emulator-5554',
    accent: '#f59e0b',
  },
];

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const escapeHtml = (text) =>
  text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

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
    <span class="tag">BUKTI EKSEKUSI</span>
  </div>
  <pre>${escapeHtml(body)}</pre>
</div>
</body></html>`;
}

const userDataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'week12-qa-'));
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

    const body = fs.readFileSync(inputPath, 'utf8').trimEnd();
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
