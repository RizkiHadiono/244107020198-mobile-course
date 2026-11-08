# Temuan Profiling — Week 11 Performance Optimization

Dokumen ini mencatat **apa yang sebenarnya terukur** pada aplikasi sebelum optimasi,
bukan dugaan. Semua angka berasal dari satu sesi profiling yang dapat diulang:

```bash
flutter build web --profile -t lib/perf_main.dart \
  --dart-define=PERF_MODE=true \
  --dart-define=PERF_IMAGE_BASE=http://127.0.0.1:8777/img \
  --output=build/perf_web

node tool/perf/server.mjs build/perf_web      # server statis + gambar deterministik
node tool/perf/run.mjs --label before         # Chrome DevTools Protocol
node tool/perf/chart.mjs --labels before      # screenshots/before-profile.png
```

Data mentah: [`tool/perf/results/before.json`](../tool/perf/results/before.json).
Trace CDP mentah (`before-trace.json`, ±27 MB) tidak di-commit karena ukurannya,
tetapi dihasilkan ulang otomatis oleh `run.mjs` pada setiap pengukuran.

---

## Metodologi singkat

| Aspek | Nilai |
| :--- | :--- |
| Build | Flutter **web profile** (`--profile`), bukan debug |
| Viewport | 390 x 844 logis, `devicePixelRatio` 2 (setara HP kelas menengah) |
| Browser | Chrome headless, `--disable-background-timer-throttling` |
| Sumber frame time | `SchedulerBinding.addTimingsCallback` (`FrameTiming`) — sumber yang sama dengan DevTools frame chart |
| Sumber fase build/layout/paint | Trace `blink.user_timing` + `devtools.timeline` via CDP |
| Data catatan | `InMemoryNoteRepository` berisi **300** catatan (deterministik) |
| Data pengumuman | `jsonplaceholder.typicode.com/photos` (`_limit=100`), gambar dari server lokal `/img/1200x800/<id>.png` |
| Skenario | 10x gulir daftar catatan → ketik pencarian 9 karakter → buka/tutup detail 5x → buka pengumuman, tunggu gambar, gulir 10x |

Skenario dijalankan oleh [`lib/perf/perf_scenario.dart`](../lib/perf/perf_scenario.dart) dan
**identik** untuk pengukuran before maupun after, sehingga selisih angka hanya berasal dari
perubahan kode aplikasi.

---

## Ringkasan baseline

| Metrik | Nilai baseline |
| :--- | ---: |
| Frame direkam | 358 |
| Frame jank (> 16,67 ms) | **22 (6,1 %)** |
| Rata-rata build (UI thread) | **8,93 ms** |
| Rata-rata raster (GPU thread) | 2,57 ms |
| p90 frame | 14,50 ms |
| Frame terburuk | **289 ms** |
| Build terburuk | 289 ms |
| Raster terburuk | 170,9 ms |
| Frame pertama (cold start) | 169 ms |
| ImageCache | **27 gambar / 103.680.000 byte (98,9 MB)** |
| Rebuild `AnnouncementCard` | **100** |
| Rebuild `NoteCard` | 166 |
| Total fase PAINT (trace) | **1.771 ms** |
| Total fase BUILD (trace) | 598 ms |
| Total fase LAYOUT (trace) | 530 ms |
| Total `Decode Image` (trace) | 295 ms |

---

## Temuan 1 — Gambar di-decode pada resolusi asli, bukan ukuran tampil

**Gejala terukur**

| Indikator | Nilai |
| :--- | ---: |
| `imageCache.currentSizeBytes` | 103.680.000 byte |
| `imageCache.currentSize` | 27 gambar |
| Rata-rata per gambar | 103.680.000 / 27 = **3.840.000 byte (3,66 MB)** |
| Total event `Decode Image` | **295 ms** |

3.840.000 byte tepat sama dengan `1200 x 800 x 4 byte` (RGBA). Artinya Flutter menyimpan
bitmap **1200x800** di memori, padahal kartu hanya menampilkannya setinggi 180 dp
(≈ 358 x 180 logis = **716 x 360 px** pada DPR 2). Luas bitmap 3,3x lebih besar dari
yang dibutuhkan.

**Penyebab di kode (baseline)**

```dart
// lib/features/announcements/presentation/pages/announcements_page.dart (baseline)
Image.network(
  imageUrl,             // .../1200x800/1.png
  height: 180,
  width: double.infinity,
  fit: BoxFit.cover,
),                      // tidak ada cacheWidth / cacheHeight
```

`Image.network` tanpa `cacheWidth`/`cacheHeight` men-decode seluruh berkas. Ukuran tampil
(`height: 180`) hanya memengaruhi *paint*, bukan *decode*.

**Dampak**

- Memori gambar ~99 MB hanya untuk 27 gambar pertama → risiko OOM di perangkat 2 GB.
- Setiap gambar baru memicu decode besar di raster thread → spike raster 170,9 ms
  dan satu frame 289 ms.
- Tidak ada batas cache eksplisit; default Flutter 1000 gambar / 100 MB.

**Rencana perbaikan** — `memCacheWidth`/`memCacheHeight` pada `CachedNetworkImage`,
ditambah batas `imageCache.maximumSize`.

---

## Temuan 2 — Daftar panjang dibangun sekaligus (tanpa pagination / lazy list)

**Gejala terukur**

| Indikator | Nilai |
| :--- | ---: |
| Rebuild `AnnouncementCard` dalam satu skenario | **100** (= seluruh dataset) |
| Total fase PAINT | **1.771 ms** |
| Total fase LAYOUT | 530 ms |
| Frame jank | 22 |

Baseline memakai:

```dart
// baseline
SingleChildScrollView(
  child: Column(
    children: state.items.map((item) => _AnnouncementCard(...)).toList(),
  ),
)
```

`Column` membangun **semua** 100 kartu sekaligus. `SingleChildScrollView` memberi
`Column` tinggi tak terbatas sehingga seluruh 100 kartu ikut di-*layout* dan di-*paint*
pada frame pertama, meskipun hanya 3 kartu terlihat.

Untuk daftar catatan, `NoteRepository.fetchNotes()` juga mengambil **seluruh** isi tabel
(`db.query('notes')` tanpa `limit`), lalu seluruh baris dipetakan menjadi entity pada
setiap pemuatan ulang.

**Dampak**

- Waktu frame pertama halaman pengumuman melonjak; total PAINT 1.771 ms terakumulasi
  sepanjang sesi.
- Memori objek widget sebanding dengan jumlah data, bukan jumlah yang terlihat.
- Bertambahnya data (100 → 1.000 pengumuman) membuat kondisi ini makin buruk secara linear.

**Rencana perbaikan** — `ListView.builder` + pagination 20 item + infinite scroll,
serta `db.query(..., limit:, offset:)` pada repository catatan.

---

## Temuan 3 — Rebuild berlebih: satu state besar menggerakkan seluruh halaman

**Gejala terukur**

- `NoteCard` dibangun **166 kali** untuk 300 catatan dalam satu sesi.
- Setiap ketikan pada kolom pencarian (`setSearchQuery`) mengubah `NotesState`,
  dan baseline memakai `ref.watch(notesNotifierProvider)` di `build()` halaman.
  Akibatnya **AppBar, FAB, header, dan seluruh daftar** ikut di-rebuild — padahal
  yang berubah hanya teks query.

**Penyebab di kode (baseline)**

```dart
// baseline
Widget build(BuildContext context) {
  final state = ref.watch(notesNotifierProvider); // seluruh state
  ...
}
```

`ref.watch` pada objek state utuh berarti setiap field yang berubah
(`isLoading`, `errorMessage`, `searchQuery`, …) memicu rebuild seluruh subtree.

Ditambah lagi setiap item membuat closure baru (`onTap: () => ...`) pada setiap build,
sehingga widget anak tidak pernah dianggap sama dan tidak bisa di-*skip*.

**Dampak**

- Build rata-rata 8,93 ms — setengah dari budget 16,67 ms habis hanya untuk rebuild
  yang tidak perlu.
- Saat mengetik, UI terasa "berat" karena setiap karakter memicu rebuild satu halaman penuh.

**Rencana perbaikan** — `ref.watch(provider.select(...))` per potongan state,
memecah halaman menjadi widget kecil, `RepaintBoundary` per item, dan hoisting closure.

---

## Temuan 4 — Tidak ada cache data; setiap kunjungan mengunduh ulang

**Gejala**

Baseline `AnnouncementRepositoryImpl.fetchAll()` selalu memanggil jaringan, tanpa cache
lokal apa pun. Membuka halaman pengumuman dua kali berarti dua unduhan penuh
(100 item + 100 URL gambar). Dalam kondisi jaringan lambat, layar kosong + spinner
selama beberapa detik pada setiap kunjungan.

**Rencana perbaikan** — strategi *stale-while-revalidate*: baca cache
(`SharedPreferences`) lebih dulu, tampilkan seketika, lalu revalidate ke server dan
perbarui cache. Saat jaringan gagal, cache dipakai sebagai fallback.

---

## Temuan 5 — Request AI tanpa timeout dan tanpa retry

**Gejala**

`AiService.sendMessage()` memanggil `_client.post(...)` tanpa `.timeout(...)`.
Pada jaringan yang menggantung, `Future` tidak pernah selesai dan indikator
"Asisten AI sedang berpikir..." berputar tanpa batas. Kegagalan 5xx yang bersifat
sementara juga langsung dilaporkan sebagai error permanen.

**Rencana perbaikan** — timeout 15 detik + retry 1x dengan backoff 400 ms untuk
5xx/timeout saja (bukan 4xx).

---

## Temuan 6 — Batas `ImageCache` memakai default framework

**Gejala**

`PaintingBinding.instance.imageCache` dibiarkan pada default: **1000 gambar / 100 MB**.
Untuk aplikasi dengan daftar bergambar panjang, batas ini terlalu longgar — cache bisa
menahan puluhan MB gambar yang tidak lagi terlihat sebelum melakukan eviction.

**Rencana perbaikan** — turunkan ke `maximumSize = 200`, `maximumSizeBytes = 60 MB`,
sekaligus menurunkan ukuran tiap entri lewat Temuan 1.

---

## Prioritas perbaikan

| Prioritas | Temuan | Alasan |
| :--- | :--- | :--- |
| **P0** | #1 Gambar resolusi asli | 98,9 MB memori + spike raster terbesar |
| **P0** | #2 Daftar dibangun sekaligus | 100 kartu, PAINT 1.771 ms |
| **P1** | #3 Rebuild berlebih | 8,93 ms build rata-rata, terasa saat mengetik |
| **P1** | #4 Tanpa cache data | UX: layar kosong setiap kunjungan |
| **P2** | #5 Tanpa timeout/retry | UX: loading tak berujung |
| **P2** | #6 Batas cache default | Pencegahan, bukan gejala utama |

Hasil pengukuran setelah keenam perbaikan diterapkan ada di
[`docs/performance-report.md`](performance-report.md).
