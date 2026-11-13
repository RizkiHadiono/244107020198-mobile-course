// Ringkasan cakupan kode dari `coverage/lcov.info`.
//
// Pemakaian:
//   flutter test --coverage
//   node tool/qa/coverage_summary.mjs
//
// Output:
//   tool/qa/results/coverage.txt   (tabel teks, dipakai untuk screenshot)
//   tool/qa/results/coverage.json  (data mentah untuk laporan)
import fs from 'node:fs';
import path from 'node:path';

const LCOV = path.resolve(process.argv[2] ?? 'coverage/lcov.info');
const OUT_DIR = path.resolve('tool/qa/results');

if (!fs.existsSync(LCOV)) {
  console.error(`File lcov tidak ditemukan: ${LCOV}`);
  console.error('Jalankan `flutter test --coverage` terlebih dahulu.');
  process.exit(1);
}

const records = [];
let current = null;

for (const rawLine of fs.readFileSync(LCOV, 'utf8').split(/\r?\n/)) {
  const line = rawLine.trim();
  if (line.startsWith('SF:')) {
    current = {
      file: line.slice(3).replace(/\\/g, '/'),
      found: 0,
      hit: 0,
      branchesFound: 0,
      branchesHit: 0,
    };
    records.push(current);
  } else if (!current) {    continue;
  } else if (line.startsWith('LF:')) {
    current.found = Number(line.slice(3));
  } else if (line.startsWith('LH:')) {
    current.hit = Number(line.slice(3));
  } else if (line.startsWith('BRF:')) {
    current.branchesFound = Number(line.slice(4));
  } else if (line.startsWith('BRH:')) {
    current.branchesHit = Number(line.slice(4));
  }
}

const pct = (hit, found) => (found === 0 ? 100 : (hit / found) * 100);

// Hanya berkas di bawah lib/ yang relevan; berkas test dan generated diabaikan.
const files = records
  .filter((r) => r.file.startsWith('lib/') || r.file.includes('/lib/'))
  .map((r) => {
    const rel = r.file.startsWith('lib/')
      ? r.file
      : r.file.slice(r.file.indexOf('/lib/') + 1);
    return { ...r, rel, percent: pct(r.hit, r.found) };
  })
  .sort((a, b) => a.percent - b.percent || a.rel.localeCompare(b.rel));

const totalFound = files.reduce((sum, f) => sum + f.found, 0);
const totalHit = files.reduce((sum, f) => sum + f.hit, 0);
const branchFound = files.reduce((sum, f) => sum + f.branchesFound, 0);
const branchHit = files.reduce((sum, f) => sum + f.branchesHit, 0);
const overall = pct(totalHit, totalFound);

const bar = (percent) => {
  const width = 24;
  const filled = Math.round((percent / 100) * width);
  return '[' + '#'.repeat(filled) + '.'.repeat(width - filled) + ']';
};

const pad = (text, width) => String(text).padEnd(width);
const padStart = (text, width) => String(text).padStart(width);

const lines = [];
lines.push('COVERAGE RINGKASAN (flutter test --coverage)');
lines.push('='.repeat(78));
lines.push(
  `${pad('Berkas', 46)} ${padStart('Baris', 10)} ${padStart('Cakupan', 9)}`,
);
lines.push('-'.repeat(78));
for (const f of files) {
  lines.push(
    `${pad(f.rel.length > 45 ? '...' + f.rel.slice(-42) : f.rel, 46)} ` +
      `${padStart(`${f.hit}/${f.found}`, 10)} ` +
      `${padStart(f.percent.toFixed(1) + '%', 9)}`,
  );
}
lines.push('-'.repeat(78));
lines.push(
  `${pad('TOTAL', 46)} ${padStart(`${totalHit}/${totalFound}`, 10)} ` +
    `${padStart(overall.toFixed(1) + '%', 9)}`,
);
lines.push('');
lines.push(`Cakupan baris keseluruhan : ${overall.toFixed(1)}%`);
lines.push(
  `Cakupan cabang (branch)   : ${
    branchFound === 0 ? 'tidak ada data cabang' : pct(branchHit, branchFound).toFixed(1) + '%'
  } (${branchHit}/${branchFound})`,
);
lines.push(`Berkas dianalisis         : ${files.length}`);
lines.push('');
lines.push('10 berkas dengan cakupan terendah:');
for (const f of files.slice(0, 10)) {
  lines.push(`  ${bar(f.percent)} ${f.percent.toFixed(1).padStart(5)}%  ${f.rel}`);
}

const text = lines.join('\n');
fs.mkdirSync(OUT_DIR, { recursive: true });
fs.writeFileSync(path.join(OUT_DIR, 'coverage.txt'), text, 'utf8');
fs.writeFileSync(
  path.join(OUT_DIR, 'coverage.json'),
  JSON.stringify(
    {
      generatedAt: new Date().toISOString(),
      overallPercent: Number(overall.toFixed(2)),
      linesFound: totalFound,
      linesHit: totalHit,
      branchesFound: branchFound,
      branchesHit: branchHit,
      files: files.map((f) => ({
        file: f.rel,
        linesFound: f.found,
        linesHit: f.hit,
        percent: Number(f.percent.toFixed(2)),
        branchesFound: f.branchesFound,
        branchesHit: f.branchesHit,
      })),
    },
    null,
    2,
  ),
  'utf8',
);

console.log(text);
console.log(`\nTersimpan: tool/qa/results/coverage.txt dan coverage.json`);
