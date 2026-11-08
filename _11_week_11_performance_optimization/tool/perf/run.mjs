// Harness profiling Flutter web memakai Chrome DevTools Protocol.
//
// Menjalankan skenario deterministik (lihat lib/perf/perf_scenario.dart),
// mengumpulkan FrameTiming dari aplikasi, mengambil heap sebelum/sesudah,
// dan menyimpan screenshot kondisi UI.
//
// Pemakaian:
//   node tool/perf/run.mjs --label before --shots screenshots
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { spawn } from 'node:child_process';

const args = process.argv.slice(2);
const arg = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i === -1 ? fallback : args[i + 1];
};

const LABEL = arg('label', 'run');
const PORT = Number(arg('port', 8777));
const DEBUG_PORT = Number(arg('debug-port', 9333));
const SHOTS = path.resolve(arg('shots', 'screenshots'));
const OUT_DIR = path.resolve('tool/perf/results');
const BASE_URL = `http://127.0.0.1:${PORT}/`;
const CHROME =
  process.env.CHROME_PATH ??
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';

fs.mkdirSync(OUT_DIR, { recursive: true });
fs.mkdirSync(SHOTS, { recursive: true });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

class Cdp {
  constructor(wsUrl) {
    this.wsUrl = wsUrl;
    this.id = 0;
    this.pending = new Map();
    this.listeners = new Map();
  }

  async connect() {
    this.ws = new WebSocket(this.wsUrl);
    await new Promise((resolve, reject) => {
      this.ws.onopen = resolve;
      this.ws.onerror = reject;
    });
    this.ws.onmessage = (event) => {
      const msg = JSON.parse(event.data);
      if (msg.id && this.pending.has(msg.id)) {
        const { resolve, reject } = this.pending.get(msg.id);
        this.pending.delete(msg.id);
        if (msg.error) reject(new Error(JSON.stringify(msg.error)));
        else resolve(msg.result);
        return;
      }
      const handlers = this.listeners.get(msg.method) ?? [];
      for (const handler of handlers) handler(msg.params);
    };
  }

  send(method, params = {}) {
    const id = ++this.id;
    this.ws.send(JSON.stringify({ id, method, params }));
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      setTimeout(() => {
        if (this.pending.has(id)) {
          this.pending.delete(id);
          reject(new Error(`CDP timeout: ${method}`));
        }
      }, 120000);
    });
  }

  on(method, handler) {
    const list = this.listeners.get(method) ?? [];
    list.push(handler);
    this.listeners.set(method, list);
  }

  close() {
    this.ws?.close();
  }
}

async function waitForEndpoint(url, timeoutMs = 30000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const res = await fetch(url);
      if (res.ok) return await res.json();
    } catch {
      /* belum siap */
    }
    await sleep(250);
  }
  throw new Error(`Endpoint tidak siap: ${url}`);
}

async function evaluate(cdp, expression) {
  const { result, exceptionDetails } = await cdp.send('Runtime.evaluate', {
    expression,
    returnByValue: true,
    awaitPromise: true,
  });
  if (exceptionDetails) {
    throw new Error(`JS error: ${exceptionDetails.text}`);
  }
  return result.value;
}

async function waitFor(predicate, timeoutMs, label) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (await predicate()) return;
    await sleep(250);
  }
  throw new Error(`Timeout menunggu ${label}`);
}

async function heapUsage(cdp) {
  await cdp.send('HeapProfiler.collectGarbage');
  await sleep(400);
  const { usedSize, totalSize } = await cdp.send('Runtime.getHeapUsage');
  return { usedBytes: usedSize, totalBytes: totalSize };
}

async function screenshot(cdp, name) {
  const { data } = await cdp.send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: false,
  });
  const file = path.join(SHOTS, name);
  fs.writeFileSync(file, Buffer.from(data, 'base64'));
  console.log(`  screenshot -> ${path.relative(process.cwd(), file)}`);
}

const userDataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'week11-chrome-'));

console.log(`[1/6] Menjalankan Chrome (headless) ...`);
const chrome = spawn(
  CHROME,
  [
    '--headless=new',
    `--remote-debugging-port=${DEBUG_PORT}`,
    `--user-data-dir=${userDataDir}`,
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-background-timer-throttling',
    '--disable-renderer-backgrounding',
    '--disable-backgrounding-occluded-windows',
    '--enable-unsafe-swiftshader',
    '--force-color-profile=srgb',
    '--hide-scrollbars',
    '--window-size=390,844',
    'about:blank',
  ],
  { stdio: 'ignore' },
);

let cdp;
let exitCode = 0;
try {
  await waitForEndpoint(`http://127.0.0.1:${DEBUG_PORT}/json/version`);

  console.log(`[2/6] Membuat tab dan mengatur viewport 390x844 @2x ...`);
  const target = await (
    await fetch(
      `http://127.0.0.1:${DEBUG_PORT}/json/new?${encodeURIComponent(
        'about:blank',
      )}`,
      { method: 'PUT' },
    )
  ).json();

  cdp = new Cdp(target.webSocketDebuggerUrl);
  await cdp.connect();
  await cdp.send('Page.enable');
  await cdp.send('Runtime.enable');
  await cdp.send('HeapProfiler.enable');
  await cdp.send('Emulation.setDeviceMetricsOverride', {
    width: 390,
    height: 844,
    deviceScaleFactor: 2,
    mobile: true,
  });

  console.log(`[3/6] Memuat aplikasi ${BASE_URL} ...`);
  await cdp.send('Page.navigate', { url: BASE_URL });
  await waitFor(
    async () =>
      (await evaluate(cdp, `typeof window.__perfStart === 'function'`)) === true,
    90000,
    'aplikasi siap',
  );
  await sleep(1500);

  const heapBefore = await heapUsage(cdp);

  console.log(`[4/6] Merekam trace dan menjalankan skenario ...`);
  const traceChunks = [];
  cdp.on('Tracing.dataCollected', (payload) => {
    traceChunks.push(...(payload.value ?? []));
  });
  const traceDone = new Promise((resolve) => {
    cdp.on('Tracing.tracingComplete', resolve);
  });
  await cdp.send('Tracing.start', {
    transferMode: 'ReportEvents',
    traceConfig: {
      includedCategories: [
        'devtools.timeline',
        'blink.user_timing',
        'v8.execute',
        'benchmark',
        'disabled-by-default-devtools.timeline',
        'disabled-by-default-devtools.timeline.frame',
      ],
    },
  });

  await evaluate(cdp, 'window.__perfStart(); true');
  await waitFor(
    async () => (await evaluate(cdp, `window.__perfState()`)) === 'done',
    180000,
    'skenario selesai',
  );

  await cdp.send('Tracing.end');
  await traceDone;

  const result = JSON.parse(await evaluate(cdp, `window.__perfResult`));
  const heapAfter = await heapUsage(cdp);

  const report = {
    label: LABEL,
    capturedAt: new Date().toISOString(),
    viewport: { width: 390, height: 844, devicePixelRatio: 2 },
    heapBefore,
    heapAfter,
    heapDeltaBytes: heapAfter.usedBytes - heapBefore.usedBytes,
    ...result,
  };

  fs.writeFileSync(
    path.join(OUT_DIR, `${LABEL}.json`),
    JSON.stringify(report, null, 2),
  );
  fs.writeFileSync(
    path.join(OUT_DIR, `${LABEL}-trace.json`),
    JSON.stringify(traceChunks),
  );

  console.log(
    `  frame=${report.frameCount} jank=${report.jankCount} ` +
      `avgBuild=${report.avgBuildMs}ms avgRaster=${report.avgRasterMs}ms ` +
      `p90=${report.p90FrameMs}ms`,
  );
  console.log(
    `  heap ${(heapBefore.usedBytes / 1048576).toFixed(1)}MB -> ` +
      `${(heapAfter.usedBytes / 1048576).toFixed(1)}MB ` +
      `(delta ${(report.heapDeltaBytes / 1048576).toFixed(2)}MB)`,
  );
  console.log(`  buildCounts=${JSON.stringify(report.buildCounts)}`);

  console.log(`[5/6] Mengambil screenshot kondisi UI ...`);
  await screenshot(cdp, '01-notes-list.png');

  await evaluate(cdp, `window.__perfGo('/chat')`);
  await sleep(1200);
  await screenshot(cdp, '05-chat-screen.png');
  await evaluate(cdp, `window.history.back()`);
  await sleep(800);

  await evaluate(cdp, `window.__perfSearch('Praktikum #12')`);
  await sleep(1200);
  await screenshot(cdp, '02-notes-search.png');
  await evaluate(cdp, `window.__perfSearch('')`);
  await sleep(600);

  await evaluate(cdp, `window.__perfGo('/notes/3')`);
  await sleep(1200);
  await screenshot(cdp, '03-note-detail.png');
  await evaluate(cdp, `window.history.back()`);
  await sleep(800);

  await evaluate(cdp, `window.__perfGo('/announcements')`);
  await sleep(4500);
  await screenshot(cdp, '04-announcements.png');

  console.log(`[6/6] Selesai. Data: tool/perf/results/${LABEL}.json`);
} catch (error) {
  console.error(`GAGAL: ${error.message}`);
  exitCode = 1;
} finally {
  cdp?.close();
  chrome.kill();
  await sleep(500);
  fs.rmSync(userDataDir, { recursive: true, force: true });
}

process.exit(exitCode);
