// Menjalankan gate yang sama persis dengan workflow GitHub Actions, lalu
// menyimpan keluarannya sebagai bukti.
//
// Pemakaian (dari folder proyek Week 13):
//   node tool/ci/local_ci.mjs
//
// Hasil:
//   tool/ci/results/01-format.txt
//   tool/ci/results/02-analyze.txt
//   tool/ci/results/03-test.txt
//   tool/ci/results/04-coverage.txt
//   tool/ci/results/local-ci.json
//
// Skrip ini sengaja tidak melonggarkan pemeriksaan apa pun. Jika sebuah gate
// gagal di sini, gate yang sama juga akan gagal di GitHub Actions.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const OUT = path.resolve('tool/ci/results');

/// Gate yang dijalankan, berurutan. `file` menjadi nama berkas bukti.
const GATES = [
  {
    file: '01-format.txt',
    label: 'dart format --output=none --set-exit-if-changed .',
    cmd: 'dart',
    args: ['format', '--output=none', '--set-exit-if-changed', '.'],
  },
  {
    file: '02-analyze.txt',
    label: 'flutter analyze --fatal-infos',
    cmd: 'flutter',
    args: ['analyze', '--fatal-infos'],
  },
  {
    file: '03-test.txt',
    label: 'flutter test --coverage',
    cmd: 'flutter',
    args: ['test', '--coverage'],
  },
];

/// Menjalankan satu perintah dan mengembalikan keluaran gabungan serta kode
/// keluar. `shell: true` dipakai karena di Windows `dart` dan `flutter`
/// berupa berkas .bat.
function run(cmd, args) {
  return new Promise((resolve) => {
    const child = spawn(cmd, args, {
      shell: true,
      cwd: process.cwd(),
      env: process.env,
    });

    let output = '';
    child.stdout.on('data', (chunk) => {
      output += chunk.toString();
      process.stdout.write(chunk);
    });
    child.stderr.on('data', (chunk) => {
      output += chunk.toString();
      process.stderr.write(chunk);
    });
    child.on('close', (code) => resolve({ code: code ?? 1, output }));
  });
}

/// Ringkasan cakupan dari `coverage/lcov.info`.
function summarizeCoverage(lcovPath) {
  if (!fs.existsSync(lcovPath)) return null;

  const records = [];
  let current = null;
  for (const raw of fs.readFileSync(lcovPath, 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    if (line.startsWith('SF:')) {
      current = {
        file: line.slice(3).replace(/\\/g, '/'),
        found: 0,
        hit: 0,
      };
      records.push(current);
    } else if (!current) {
      continue;
    } else if (line.startsWith('LF:')) {
      current.found = Number(line.slice(3));
    } else if (line.startsWith('LH:')) {
      current.hit = Number(line.slice(3));
    }
  }

  const lib = records.filter((r) => r.file.startsWith('lib/'));
  const found = lib.reduce((s, r) => s + r.found, 0);
  const hit = lib.reduce((s, r) => s + r.hit, 0);
  return {
    files: lib.length,
    linesFound: found,
    linesHit: hit,
    percent: found === 0 ? 0 : Number(((hit / found) * 100).toFixed(2)),
  };
}

fs.mkdirSync(OUT, { recursive: true });

const summary = {
  startedAt: new Date().toISOString(),
  workingDirectory: process.cwd(),
  gates: [],
};

let failed = false;

for (const gate of GATES) {
  console.log(`\n=== ${gate.label} ===`);
  const startedAt = Date.now();
  const result = await run(gate.cmd, gate.args);
  const durationMs = Date.now() - startedAt;

  // Beri header agar berkas bukti dapat dibaca tanpa konteks tambahan.
  const body = [
    `$ ${gate.label}`,
    '',
    result.output.trimEnd(),
    '',
    `exit code: ${result.code}`,
    `durasi   : ${(durationMs / 1000).toFixed(1)} detik`,
    '',
  ].join('\n');

  fs.writeFileSync(path.join(OUT, gate.file), body, 'utf8');

  summary.gates.push({
    label: gate.label,
    file: gate.file,
    exitCode: result.code,
    durationMs,
  });

  if (result.code !== 0) {
    failed = true;
    console.error(`GAGAL: ${gate.label} (exit ${result.code})`);
    // Berhenti pada kegagalan pertama, sama seperti GitHub Actions yang
    // menghentikan job ketika satu step gagal.
    break;
  }
}

if (!failed) {
  const coverage = summarizeCoverage(path.resolve('coverage/lcov.info'));
  if (coverage) {
    const lines = [
      'RINGKASAN CAKUPAN (coverage/lcov.info)',
      '='.repeat(46),
      `Berkas dianalisis : ${coverage.files}`,
      `Baris dieksekusi  : ${coverage.linesHit}/${coverage.linesFound}`,
      `Cakupan baris     : ${coverage.percent}%`,
      '',
      'Angka ini hanya menghitung test unit dan widget, karena integration',
      'test membutuhkan emulator dan tidak dijalankan di CI.',
      '',
    ].join('\n');
    fs.writeFileSync(path.join(OUT, '04-coverage.txt'), lines, 'utf8');
    summary.coverage = coverage;
    console.log(`\nCakupan baris: ${coverage.percent}%`);
  }
}

summary.finishedAt = new Date().toISOString();
summary.status = failed ? 'failed' : 'passed';
fs.writeFileSync(
  path.join(OUT, 'local-ci.json'),
  `${JSON.stringify(summary, null, 2)}\n`,
  'utf8',
);

console.log(`\nStatus akhir: ${summary.status}`);
console.log(`Bukti tersimpan di ${path.relative(process.cwd(), OUT)}`);
process.exit(failed ? 1 : 0);
