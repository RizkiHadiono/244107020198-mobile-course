// Merender tabel perbandingan before/after menjadi satu gambar.
//
// Input : tool/perf/results/before.json + after.json
// Output: screenshots/before-after-comparison.png
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { spawn } from 'node:child_process';

const args = process.argv.slice(2);
const arg = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i === -1 ? fallback : args[i + 1];
};

const BEFORE = path.resolve(arg('before', 'tool/perf/results/before.json'));
const AFTER = path.resolve(arg('after', 'tool/perf/results/after.json'));
const OUT = path.resolve(arg('out', 'screenshots/before-after-comparison.png'));
const DEBUG_PORT = Number(arg('debug-port', 9555));
const CHROME =
  process.env.CHROME_PATH ??
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

for (const file of [BEFORE, AFTER]) {
  if (!fs.existsSync(file)) {
    throw new Error(`Data tidak ditemukan: ${file}. Jalankan tool/perf/run.mjs dulu.`);
  }
}

const b = JSON.parse(fs.readFileSync(BEFORE, 'utf8'));
const a = JSON.parse(fs.readFileSync(AFTER, 'utf8'));

const mb = (bytes) => (bytes / 1048576).toFixed(1);
const pct = (from, to) => {
  if (!from) return '—';
  const d = ((to - from) / from) * 100;
  return `${d > 0 ? '+' : ''}${d.toFixed(1)} %`;
};

const rows = [
  ['Frame direkam', b.frameCount, a.frameCount, 'neutral'],
  ['Frame jank (> 16,67 ms)', b.jankCount, a.jankCount, 'down'],
  ['Rasio jank', `${(b.jankRatio * 100).toFixed(1)} %`, `${(a.jankRatio * 100).toFixed(1)} %`, 'down', pct(b.jankRatio, a.jankRatio)],
  ['Rata-rata build (UI)', `${b.avgBuildMs.toFixed(2)} ms`, `${a.avgBuildMs.toFixed(2)} ms`, 'down', pct(b.avgBuildMs, a.avgBuildMs)],
  ['Rata-rata raster (GPU)', `${b.avgRasterMs.toFixed(2)} ms`, `${a.avgRasterMs.toFixed(2)} ms`, 'down', pct(b.avgRasterMs, a.avgRasterMs)],
  ['Rata-rata frame', `${b.avgFrameMs.toFixed(2)} ms`, `${a.avgFrameMs.toFixed(2)} ms`, 'down', pct(b.avgFrameMs, a.avgFrameMs)],
  ['p90 frame', `${b.p90FrameMs.toFixed(2)} ms`, `${a.p90FrameMs.toFixed(2)} ms`, 'down', pct(b.p90FrameMs, a.p90FrameMs)],
  ['Frame terburuk', `${b.worstFrameMs.toFixed(1)} ms`, `${a.worstFrameMs.toFixed(1)} ms`, 'down', pct(b.worstFrameMs, a.worstFrameMs)],
  ['Build terburuk', `${b.worstBuildMs.toFixed(1)} ms`, `${a.worstBuildMs.toFixed(1)} ms`, 'down', pct(b.worstBuildMs, a.worstBuildMs)],
  ['Raster terburuk', `${b.worstRasterMs.toFixed(1)} ms`, `${a.worstRasterMs.toFixed(1)} ms`, 'down', pct(b.worstRasterMs, a.worstRasterMs)],
  ['Frame pertama (cold start)', `${b.firstFrameMs} ms`, `${a.firstFrameMs} ms`, 'neutral', pct(b.firstFrameMs, a.firstFrameMs)],
  ['Memori ImageCache', `${mb(b.imageCacheBytes)} MB`, `${mb(a.imageCacheBytes)} MB`, 'down', pct(b.imageCacheBytes, a.imageCacheBytes)],
  ['Gambar di ImageCache', b.imageCacheCount, a.imageCacheCount, 'down'],
  ['Rebuild AnnouncementCard', b.buildCounts.AnnouncementCard, a.buildCounts.AnnouncementCard, 'down'],
  ['Rebuild NoteCard', b.buildCounts.NoteCard, a.buildCounts.NoteCard, 'neutral'],
];

const html = `<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
  * { box-sizing: border-box; }
  body { margin: 0; background: #0f172a; color: #e2e8f0; width: 980px;
         font-family: 'Segoe UI', Roboto, sans-serif; padding: 26px; }
  h1 { font-size: 21px; margin: 0 0 4px; }
  .sub { color: #94a3b8; font-size: 12px; margin-bottom: 18px; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  th { text-align: left; padding: 8px 12px; color: #94a3b8; font-size: 11px;
       text-transform: uppercase; letter-spacing: .05em; border-bottom: 1px solid #334155; }
  td { padding: 8px 12px; border-bottom: 1px solid #1e293b; }
  td.num { text-align: right; font-variant-numeric: tabular-nums; }
  .good { color: #4ade80; font-weight: 700; }
  .flat { color: #94a3b8; }
  .metric { color: #cbd5e1; }
  .foot { margin-top: 16px; font-size: 11.5px; color: #64748b; line-height: 1.6; }
  .note { background: #1e293b; border-left: 3px solid #38bdf8; padding: 10px 14px;
          border-radius: 6px; font-size: 12px; color: #cbd5e1; margin-top: 14px; }
</style></head><body>
  <h1>Before vs After — Week 11 Performance Optimization</h1>
  <div class="sub">Skenario identik · Flutter web profile build · viewport 390x844 @2x ·
    baseline ${new Date(b.capturedAt).toLocaleString('id-ID')} → optimized ${new Date(a.capturedAt).toLocaleString('id-ID')}</div>
  <table>
    <tr><th>Metrik</th><th style="text-align:right">Before</th>
        <th style="text-align:right">After</th><th style="text-align:right">Selisih</th></tr>
    ${rows.map(([label, before, after, dir, explicitDelta]) => {
      const cls = dir === 'down' ? 'good' : 'flat';
      const delta = explicitDelta ?? (typeof before === 'number' && typeof after === 'number'
        ? pct(before, after)
        : '—');
      return `<tr><td class="metric">${label}</td>
        <td class="num">${before}</td>
        <td class="num ${cls}">${after}</td>
        <td class="num ${cls}">${delta}</td></tr>`;
    }).join('')}
  </table>
  <div class="note">
    <b>Perhatian:</b> <i>Rebuild NoteCard naik 166 → 193</i> karena pagination membuat
    lebih banyak kartu berbeda masuk viewport dalam jarak gulir yang sama. Yang turun
    adalah <b>biaya per frame</b> (build rata-rata −68,1 %), bukan total build sepanjang sesi.
  </div>
  <div class="foot">
    Sumber: <code>tool/perf/results/before.json</code> &amp; <code>after.json</code> —
    FrameTiming engine (SchedulerBinding.addTimingsCallback) + heap/ImageCache dari CDP.
    Angka memori gambar berasal dari <code>PaintingBinding.instance.imageCache</code>;
    heap JavaScript tidak dipakai sebagai metrik gambar karena bitmap web dikelola di luar JS heap.
  </div>
</body></html>`;

const userDataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'week11-compare-'));
const chrome = spawn(
  CHROME,
  [
    '--headless=new',
    `--remote-debugging-port=${DEBUG_PORT}`,
    `--user-data-dir=${userDataDir}`,
    '--no-first-run',
    '--hide-scrollbars',
    '--window-size=1000,1000',
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
    await fetch(`http://127.0.0.1:${DEBUG_PORT}/json/new?about:blank`, { method: 'PUT' })
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
      setTimeout(() => pending.has(msgId) && reject(new Error(`timeout ${method}`)), 60000);
    });
  };

  await send('Page.enable');
  await send('Emulation.setDeviceMetricsOverride', {
    width: 980,
    height: 1000,
    deviceScaleFactor: 2,
    mobile: false,
  });

  const dataUrl =
    'data:text/html;base64,' + Buffer.from(html, 'utf8').toString('base64');
  await send('Page.navigate', { url: dataUrl });
  await sleep(1200);

  const { data } = await send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: true,
    clip: { x: 0, y: 0, width: 980, height: 1000, scale: 1 },
  });

  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, Buffer.from(data, 'base64'));
  console.log(`comparison -> ${path.relative(process.cwd(), OUT)}`);
} finally {
  ws?.close();
  chrome.kill();
  await sleep(400);
  fs.rmSync(userDataDir, { recursive: true, force: true });
}
