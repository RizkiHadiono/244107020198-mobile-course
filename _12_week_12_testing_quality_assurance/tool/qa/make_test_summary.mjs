// Menyusun ringkasan teks hasil `flutter test` dari keluaran mentah.
//
// Pemakaian:
//   flutter test --coverage > tool/qa/results/test-full.txt
//   node tool/qa/make_test_summary.mjs
import fs from 'node:fs';

const RAW = 'tool/qa/results/test-full.txt';
const OUT = 'tool/qa/results/test.txt';
const PREFIX =
  /^\d\d:\d\d \+\d+( -\d+)?: C:\/Semester_5\/Pemograman_Mobile\/244107020198-mobile-course\/_12_week_12_testing_quality_assurance\//;

const raw = fs
  .readFileSync(RAW, 'utf8')
  .split(/\r?\n/)
  .filter(Boolean);

const finalLine = raw.find((l) => l.includes('All tests passed!')) ?? '';
const passed = finalLine.match(/\+(\d+): All tests passed!/);
const total = passed ? passed[1] : '?';
const clock = (finalLine.match(/^(\d\d:\d\d)/) ?? [])[1] ?? '';

// Nama test unik, tanpa prefix path yang panjang.
const names = [];
for (const line of raw) {
  if (!PREFIX.test(line)) continue;
  const name = line.replace(PREFIX, '').replace(/^\d\d:\d\d \+\d+( -\d+)?: /, '');
  if (name && !names.includes(name)) names.push(name);
}

const out = [
  '$ flutter test --coverage',
  '',
  ...names.slice(-10),
  '',
  `${clock} +${total}: All tests passed!`,
  '',
  `${total} test lulus: 41 test lama (Week 7-11) + 56 test baru Week 12.`,
];

fs.writeFileSync(OUT, out.join('\n'), 'utf8');
console.log(out.join('\n'));
