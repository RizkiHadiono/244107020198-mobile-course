// Merender gambar "profile report" dari data pengukuran nyata.
//
// Input : tool/perf/results/<label>.json  (FrameTiming engine + trace CDP)
// Output: screenshots/<label>-profile.png
//
// Gambar memuat frame chart (warna hijau/kuning/merah seperti DevTools),
// ringkasan metrik, dan agregasi durasi fase build/layout/paint/decode dari
// trace Chrome DevTools Protocol.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { spawn } from 'node:child_process';

const args = process.argv.slice(2);
const arg = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i === -1 ? fallback : args[i + 1];
};

const LABELS = (arg('labels', 'before,after') ?? 'before,after').split(',');
const OUT = path.resolve(arg('out', 'screenshots'));
const DEBUG_PORT = Number(arg('debug-port', 9444));
const CHROME =
  process.env.CHROME_PATH ??
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const PHASES = ['BUILD', 'LAYOUT', 'PAINT', 'Decode Image', 'PrePaint'];

function phaseTotals(traceFile) {
  if (!fs.existsSync(traceFile)) return {};
  const events = JSON.parse(fs.readFileSync(traceFile, 'utf8'));
  const totals = {};
  const open = new Map();

  for (const event of events) {
    if (!PHASES.includes(event.name)) continue;

    if (typeof event.dur === 'number') {
      totals[event.name] = (totals[event.name] ?? 0) + event.dur / 1000;
      continue;
    }

    // Flutter web mengirim event build/layout/paint sebagai pasangan async
    // begin/end (ph 'b'/'e') yang dipasangkan lewat id2.local.
    const key = `${event.name}:${event.id2?.local ?? event.id ?? ''}:${event.tid}`;
    if (event.ph === 'b' || event.ph === 'B') {
      open.set(key, event.ts);
    } else if (event.ph === 'e' || event.ph === 'E') {
      const start = open.get(key);
      if (start === undefined) continue;
      open.delete(key);
      totals[event.name] = (totals[event.name] ?? 0) + (event.ts - start) / 1000;
    }
  }
  return totals;
}

function topEvents(traceFile, limit = 8) {
  if (!fs.existsSync(traceFile)) return [];
  const events = JSON.parse(fs.readFileSync(traceFile, 'utf8'));
  const ignored = new Set([
    'RunTask',
    'Graphics.Pipeline',
    'UserTiming::Measure',
    'FunctionCall',
    'UpdateCounters',
    'V8.HandleInterrupts',
    'V8.StackGuard',
    'V8.BytecodeBudgetInterrupt',
    'PipelineReporter',
    'AnimationFrame',
    'BeginImplFrameToSendBeginMainFrame',
    'LayerTreeHostImpl::CommitComplete',
    'Commit',
    'LayerTreeHostImpl::ActivateSyncTree',
    'EndActivateToSubmitCompositorFrame',
    'ReceiveCompositorFrameToStartDraw',
    'SubmitCompositorFrameToPresentationCompositorFrame',
    'SubmitToReceiveCompositorFrame',
    'StartDrawToSwapStart',
    'SwapEndToPresentationCompositorFrame',
    'ProxyImpl::ReadyToActivate',
    'ProxyImpl::Commit',
    'Swap',
    'GPUTask',
  ]);

  const totals = new Map();
  for (const event of events) {
    if (typeof event.dur !== 'number') continue;
    if (ignored.has(event.name)) continue;
    if (event.name.startsWith('V8.')) continue;
    totals.set(event.name, (totals.get(event.name) ?? 0) + event.dur / 1000);
  }
  return [...totals.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit)
    .map(([name, ms]) => ({ name, ms }));
}

const datasets = LABELS.map((label) => {
  const jsonFile = path.resolve(`tool/perf/results/${label}.json`);
  if (!fs.existsSync(jsonFile)) {
    throw new Error(`Data tidak ditemukan: ${jsonFile}. Jalankan tool/perf/run.mjs dulu.`);
  }
  const data = JSON.parse(fs.readFileSync(jsonFile, 'utf8'));
  const traceFile = path.resolve(`tool/perf/results/${label}-trace.json`);
  return {
    ...data,
    phases: phaseTotals(traceFile),
    hotspots: topEvents(traceFile),
  };
});

function buildHtml() {
  return `<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
  * { box-sizing: border-box; }
  body { margin: 0; background: #0f172a; color: #e2e8f0;
         font-family: 'Segoe UI', Roboto, sans-serif; padding: 26px; width: 1120px; }
  h1 { font-size: 21px; margin: 0 0 4px; }
  h2 { font-size: 14px; margin: 22px 0 8px; color: #93c5fd; text-transform: uppercase;
       letter-spacing: .06em; }
  .sub { color: #94a3b8; font-size: 12px; }
  .cards { display: flex; gap: 10px; margin-top: 16px; }
  .card { flex: 1; background: #1e293b; border: 1px solid #334155; border-radius: 10px;
          padding: 12px 14px; }
  .card .k { font-size: 11px; color: #94a3b8; text-transform: uppercase; letter-spacing: .05em; }
  .card .v { font-size: 22px; font-weight: 700; margin-top: 4px; }
  .card .u { font-size: 11px; color: #64748b; }
  .good { color: #4ade80; } .warn { color: #fbbf24; } .bad { color: #f87171; }
  canvas { display: block; background: #111827; border-radius: 10px; border: 1px solid #334155; }
  .legend { display: flex; gap: 18px; font-size: 11px; color: #94a3b8; margin-top: 8px; }
  .dot { width: 9px; height: 9px; border-radius: 50%; display: inline-block; margin-right: 5px; }
  table { width: 100%; border-collapse: collapse; font-size: 12.5px; }
  th, td { text-align: left; padding: 7px 10px; border-bottom: 1px solid #1e293b; }
  th { color: #94a3b8; font-weight: 600; font-size: 11px; text-transform: uppercase; }
  td.num { text-align: right; font-variant-numeric: tabular-nums; }
  .bars { display: grid; grid-template-columns: 190px 1fr 74px; gap: 6px 10px;
          font-size: 12px; align-items: center; }
  .track { height: 16px; background: #1e293b; border-radius: 4px; overflow: hidden; }
  .fill { height: 100%; background: linear-gradient(90deg, #2563eb, #38bdf8); }
  .two { display: grid; grid-template-columns: 1fr 1fr; gap: 22px; }
</style></head><body>
  <h1 id="title"></h1>
  <div class="sub" id="subtitle"></div>
  <div class="cards" id="cards"></div>

  <h2>Frame chart — build + raster per frame (budget 16,67 ms)</h2>
  <canvas id="frames" width="1068" height="210"></canvas>
  <div class="legend">
    <span><i class="dot" style="background:#4ade80"></i>mulus (&le; 16,67 ms)</span>
    <span><i class="dot" style="background:#fbbf24"></i>borderline (16,67–33 ms)</span>
    <span><i class="dot" style="background:#f87171"></i>jank (&gt; 33 ms)</span>
    <span><i class="dot" style="background:#38bdf8"></i>garis raster</span>
  </div>

  <h2>Durasi fase dari trace Chrome DevTools</h2>
  <div class="bars" id="phases"></div>

  <h2>Event paling mahal (total durasi)</h2>
  <div class="two">
    <div><table id="hot"></table></div>
    <div>
      <h2 style="margin-top:0">Ringkasan</h2>
      <table id="summary"></table>
    </div>
  </div>

<script>
const DATA = ${JSON.stringify(datasets)};
const d = DATA[0];
const budget = d.frameBudgetMs || 16.67;
document.getElementById('title').textContent =
  'Flutter Web Profile — ' + (d.label === 'before' ? 'BEFORE (baseline)' : 'AFTER (optimized)');
document.getElementById('subtitle').textContent =
  'Skenario identik: daftar 300 catatan → scroll 10x → ketik pencarian → detail 5x → pengumuman + gambar (gulir 10x). ' +
  'Direkam ' + new Date(d.capturedAt).toLocaleString('id-ID') + ' · Flutter web profile build · viewport 390x844 @2x';

const fmt = (v, digits = 2) => (v === null || v === undefined ? '—' : Number(v).toFixed(digits));
const cls = (v, warn, bad) => (v >= bad ? 'bad' : v >= warn ? 'warn' : 'good');

const cards = [
  { k: 'Frame direkam', v: d.frameCount, u: 'frame', c: '' },
  { k: 'Jank', v: d.jankCount, u: (d.jankRatio * 100).toFixed(1) + '% frame', c: cls(d.jankCount, 1, 10) },
  { k: 'Rata-rata build', v: fmt(d.avgBuildMs), u: 'ms (UI thread)', c: cls(d.avgBuildMs, 8, 16.67) },
  { k: 'Rata-rata raster', v: fmt(d.avgRasterMs), u: 'ms (GPU thread)', c: cls(d.avgRasterMs, 8, 16.67) },
  { k: 'p90 frame', v: fmt(d.p90FrameMs), u: 'ms', c: cls(d.p90FrameMs, 16.67, 33) },
  { k: 'Frame terburuk', v: fmt(d.worstFrameMs), u: 'ms', c: cls(d.worstFrameMs, 33, 60) },
  { k: 'Heap setelah skenario', v: ((d.heapAfter?.usedBytes ?? 0) / 1048576).toFixed(1), u: 'MB (+' + ((d.heapDeltaBytes ?? 0) / 1048576).toFixed(2) + ' MB)', c: '' },
];
document.getElementById('cards').innerHTML = cards.map(c =>
  '<div class="card"><div class="k">' + c.k + '</div>' +
  '<div class="v ' + c.c + '">' + c.v + '</div><div class="u">' + c.u + '</div></div>'
).join('');

// ---- frame chart ----
const canvas = document.getElementById('frames');
const ctx = canvas.getContext('2d');
const W = canvas.width, H = canvas.height;
const padL = 42, padB = 26, padT = 12, padR = 8;
const frames = d.frames || [];
const capMs = 120;
const maxMs = Math.min(capMs, Math.max(40, ...frames.map(f => Math.max(f.build, f.raster))));
const scaleY = v => H - padB - (Math.min(v, maxMs) / maxMs) * (H - padT - padB);

ctx.clearRect(0, 0, W, H);
ctx.strokeStyle = '#1f2937'; ctx.fillStyle = '#64748b'; ctx.font = '10px Segoe UI';
for (const g of [0, 16.67, 33.3, 60, 90, 120]) {
  if (g > maxMs) continue;
  const y = scaleY(g);
  ctx.beginPath(); ctx.moveTo(padL, y); ctx.lineTo(W - padR, y); ctx.stroke();
  ctx.fillText(g === 0 ? '0 ms' : g.toFixed(1) + ' ms', 4, y + 3);
}
ctx.setLineDash([4, 4]); ctx.strokeStyle = '#f87171';
ctx.beginPath(); ctx.moveTo(padL, scaleY(budget)); ctx.lineTo(W - padR, scaleY(budget)); ctx.stroke();
ctx.setLineDash([]);

const plotW = W - padL - padR;
const barW = Math.max(1, plotW / frames.length);
frames.forEach((f, i) => {
  const m = Math.max(f.build, f.raster);
  const x = padL + i * barW;
  const color = m <= budget ? '#4ade80' : m <= 33 ? '#fbbf24' : '#f87171';
  ctx.fillStyle = color;
  ctx.fillRect(x, scaleY(m), Math.max(1, barW - 0.6), H - padB - scaleY(m));
  if (barW > 3) {
    ctx.fillStyle = '#38bdf8';
    ctx.fillRect(x, scaleY(f.raster), Math.max(1, barW - 0.6), 1.4);
  }
});
ctx.fillStyle = '#64748b';
ctx.fillText('frame #' + (frames[0]?.frame ?? 0), padL, H - 8);
ctx.fillText('frame #' + (frames.at(-1)?.frame ?? 0), W - padR - 62, H - 8);

// ---- phase bars ----
const phases = Object.entries(d.phases || {}).sort((a, b) => b[1] - a[1]);
const maxPhase = Math.max(1, ...phases.map(p => p[1]));
document.getElementById('phases').innerHTML = phases.map(([name, ms]) =>
  '<div>' + name + '</div>' +
  '<div class="track"><div class="fill" style="width:' + (ms / maxPhase * 100).toFixed(1) + '%"></div></div>' +
  '<div class="num">' + ms.toFixed(0) + ' ms</div>'
).join('');

// ---- hotspots ----
document.getElementById('hot').innerHTML =
  '<tr><th>Event</th><th style="text-align:right">Total</th></tr>' +
  (d.hotspots || []).map(h =>
    '<tr><td>' + h.name + '</td><td class="num">' + h.ms.toFixed(0) + ' ms</td></tr>'
  ).join('');

document.getElementById('summary').innerHTML =
  '<tr><th>Metrik</th><th style="text-align:right">Nilai</th></tr>' +
  [
    ['Frame pertama (cold start)', fmt(d.firstFrameMs) + ' ms'],
    ['Build terburuk', fmt(d.worstBuildMs) + ' ms'],
    ['Raster terburuk', fmt(d.worstRasterMs) + ' ms'],
    ['Rebuild NoteCard', d.buildCounts?.NoteCard ?? '—'],
    ['Rebuild AnnouncementCard', d.buildCounts?.AnnouncementCard ?? '—'],
    ['Image cache (item)', d.imageCacheCount ?? '—'],
    ['Heap sebelum', ((d.heapBefore?.usedBytes ?? 0) / 1048576).toFixed(1) + ' MB'],
    ['Heap sesudah', ((d.heapAfter?.usedBytes ?? 0) / 1048576).toFixed(1) + ' MB'],
  ].map(([k, v]) => '<tr><td>' + k + '</td><td class="num">' + v + '</td></tr>').join('');
</script>
</body></html>`;
}

const userDataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'week11-chart-'));
const chrome = spawn(
  CHROME,
  [
    '--headless=new',
    `--remote-debugging-port=${DEBUG_PORT}`,
    `--user-data-dir=${userDataDir}`,
    '--no-first-run',
    '--hide-scrollbars',
    '--window-size=1200,1400',
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
    } catch { /* belum siap */ }
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
    width: 1200,
    height: 1400,
    deviceScaleFactor: 2,
    mobile: false,
  });

  const html = buildHtml();
  fs.writeFileSync(path.resolve('tool/perf/results/report.html'), html);
  const dataUrl =
    'data:text/html;base64,' + Buffer.from(html, 'utf8').toString('base64');
  await send('Page.navigate', { url: dataUrl });
  await sleep(1200);

  const { data } = await send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: true,
    clip: { x: 0, y: 0, width: 1200, height: 1400, scale: 1 },
  });

  fs.mkdirSync(OUT, { recursive: true });
  const outFile = path.join(OUT, `${datasets[0].label}-profile.png`);
  fs.writeFileSync(outFile, Buffer.from(data, 'base64'));
  console.log(`chart -> ${path.relative(process.cwd(), outFile)}`);
} finally {
  ws?.close();
  chrome.kill();
  await sleep(400);
  fs.rmSync(userDataDir, { recursive: true, force: true });
}
