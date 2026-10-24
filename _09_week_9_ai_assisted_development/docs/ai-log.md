# AI Log — Week 9 (AI-Assisted Development / Vibe Coding)

Dokumen ini memenuhi **AI Prompt Challenge**, **AI Verification Checklist**, dan **Refactoring Challenge** codelab Week 9.
Peran AI: generator + reviewer awal. Keputusan final diambil mahasiswa setelah verifikasi bukti.

**Fitur yang ditambahkan:** Pencarian judul catatan (search) + empty state pada `_07_week_7_clean_architecture/`.

---

## 1. Prompt Inti (Formula 5 Slot) — disimpan mentah

```
Peran  : senior Flutter dev
Konteks: project Week 7, feature-first Clean Architecture
         (presentation -> domain <- data), Riverpod Notifier, SQLite.
         Struktur: lib/core, lib/features/notes/{domain,data,presentation}.
         Versi: flutter_riverpod ^3.4.3, sqflite ^2.4.4 (lihat pubspec.yaml).
Tugas  : tambah search judul notes + empty state.
Batas  : jangan ubah arsitektur; domain tetap murni Dart (tanpa Flutter/SQLite/Dio);
         maks 80 baris; jangan panggil SQLite dari widget.
Output : kode + 3 test case + cara uji.
```

**Konteks yang ditempel ke AI:** isi `note.dart` (entity), `notes_providers.dart` (Notifier & state), dan `pubspec.yaml` (versi package). **Tidak** ada token/secret yang ditempel (auth project ini simulasi lokal).

## 2. Output Awal AI (Draft — sebelum verifikasi)

AI mengusulkan tiga potongan kode berikut. **[TANDA ⚠ = halusinasi/kelemahan yang kemudian dibuktikan]**

> **Potongan 1 — fungsi filter:**
> ```dart
> List<Note> filterNotes(List<Note> notes, String query) {
>   return notes.where((n) => n.title.contains(query)).toList();   // ⚠ case-sensitive
> }
> ```

> **Potongan 2 — widget search bar (disarankan langsung di NotesPage.build):**
> ```dart
> TextField(onChanged: (v) => ref.read(notesProvider.notifier).search(v)) // ⚠ nama provider salah
> ```

> **Potongan 3 — "optimasi" AI:**
> ```dart
> // AI: "agar hemat rebuild, simpan hasil filter di dalam SQLite"
> final rows = await db.query('notes', where: 'title LIKE ?', whereArgs: ['%$q%']); // ⚠ SQL injection risk
> ```

## 3. Verifikasi 6 Langkah (bukti nyata)

| Langkah | Hasil | Bukti |
|---|---|---|
| 1. Baca tiap baris | Potongan 1 lolos sintaks tapi menyimpan bug logika | lihat temuan H1 |
| 2. Cek import domain steril | `domain/` & `core/` 0 impor Flutter/SQLite/Dio | `../screenshots/bukti-04-grep-sterilitas.txt` (exit 1 = bersih) |
| 3. Cek API nyata | `notesProvider` **tidak ada** — yang ada `notesNotifierProvider`; `contains()` case-sensitive | `git grep notesProvider` → hanya `notesNotifierProvider` |
| 4. `flutter analyze` | No issues found | `../screenshots/bukti-01-flutter-analyze.txt` |
| 5. Test sukses + gagal | 4 unit test + 2 widget test, semua hijau | `../screenshots/bukti-02-flutter-test.txt` (21/21) |
| 6. Uji manual 3 query | kosong→semua; cocok→terfilter; tak cocok→empty state | `test/search_filter_test.dart` |

## 4. Halusinasi / Bug AI yang Terbukti (bukti wajib)

| # | Temuan | Cara membuktikan | Status |
|---|---|---|---|
| **H1** | **Logika yakin-tapi-salah:** filter case-sensitive `'Belajar'.contains('belajar')` → false, sehingga query huruf kecil tidak menemukan judul huruf besar | Test merah: `search('belajar')` pada data `Belajar Clean Architecture` mengembalikan 0, padahal harusnya 1. Diperbaiki dengan `toLowerCase()` di kedua sisi → test hijau | ✅ Terbukti & diperbaiki |
| **H2** | **Method/provider fiktif:** AI memakai `notesProvider` yang tidak ada di kode | `git grep "notesProvider"` → tidak ada kecocokan; yang tersedia `notesNotifierProvider`. Diperbaiki dengan merujuk provider nyata | ✅ Terbukti & diperbaiki |
| **H3** | **Saran berbahaya:** filter via `LIKE '%$q%'` langsung ke SQLite dari layer UI → rawan *SQL injection* & melanggar dependency rule | Dependency rule Week 7 melarang domain/UI menyentuh SQL; filter daftar kecil cukup di memori. Ditolak | ❌ Ditolak beralasan |

## 5. Tabel Usulan-vs-Keputusan (AI Verification Checklist)

| Usulan AI | Keputusan | Alasan teknis |
|---|---|---|
| `filterNotes` case-sensitive di widget | **Tolak + tulis manual** → pindahkan ke `core/format.dart` sebagai `filterByTitle` generik + `toLowerCase()` | Aturan filter adalah logika bisnis → wajib di domain agar bisa diunit-test tanpa widget (Refactoring Challenge #2) |
| Panggil `notesProvider.notifier` | **Tolak + tulis manual** → gunakan `notesNotifierProvider` + `SearchNotes` use case | Provider yang disebut AI tidak ada (H2) |
| Filter via SQL `LIKE` di UI | **Tolak** | Melanggar dependency rule + risiko injection (H3); daftar notes kecil, filter in-memory sudah cukup |
| Tambah use case `SearchNotes` murni Dart | **Terima + refactor** | Sejalan dependency rule; `SearchNotes` ditempatkan di `domain/usecases/` |
| Empty state terpisah untuk "tidak cocok" vs "belum ada" | **Terima + refactor** | UX lebih jelas; ditandai `Key('notesSearchEmptyState')` agar testable |

## 6. Keputusan Final per File

| File | Keputusan |
|---|---|
| `lib/core/format.dart` | **Terima + refactor** — tambah `filterByTitle` generik (memakai `sanitizeInput` yang sebelumnya dead code) |
| `lib/features/notes/domain/usecases/search_notes.dart` | **Terima** — use case murni baru |
| `lib/features/notes/presentation/providers/notes_providers.dart` | **Terima + refactor** — tambah `searchNotesProvider`, `searchQuery` di state, `setSearchQuery`, dan **`visibleNotesProvider`** (Provider turunan reaktif; menggantikan getter `visibleNotes` yang tidak reaktif — temuan R1) |
| `lib/features/notes/presentation/pages/notes_page.dart` | **Terima + refactor** — `NotesPage` jadi `ConsumerStatefulWidget` agar `_searchController` di-`dispose()` (menutup temuan F3 Week 8), tambah search bar + empty state |
| `test/search_filter_test.dart` | **Terima** — 4 unit test (kosong/case-insensitive/sebagian-kata/tak-cocok) |
| `test/search_empty_state_test.dart` | **Terima** — 2 widget test empty state |

## 7. Pemetaan Refactoring Challenge

1. ✅ Kode AI yang semula filter di widget **dipindah ke use case domain murni** (`SearchNotes`).
2. ✅ Fungsi dipecah kecil (semua < 40 baris); filter generik `filterByTitle` bisa diuji tanpa widget.
3. ✅ Tidak ada import lintas layer — grep sterilitas tetap 0 temuan.

## 8. Prompt Review Kedua (hal. #5 codelab — AI Challenge)

Setelah fitur selesai diimplementasi, kode search diminta direview ulang oleh AI sebagai senior dev (prompt terpisah dari prompt generate):

```
Review kode search Flutter ini sebagai senior dev.
Konteks: feature-first (presentation->domain<-data), Riverpod, SQLite + Dio.
Fokus: kebenaran, arsitektur, test. Abaikan style.
Beri 3 temuan + level blocker/saran + alasan.
```

**Output AI (3 temuan) & verifikasi mahasiswa:**

| # | Temuan AI | Level | Verifikasi (bukti) | Keputusan |
|---|---|---|---|---|
| R1 | "Filter dihitung lewat getter `visibleNotes` yang dipanggil via `ref.read(notifier)` di `_buildBody` — **tidak reaktif**; UI bisa menampilkan daftar basi saat query berubah" | **blocker** | ✅ Terbukti: `notes_page.dart` memakai `ref.read(notesNotifierProvider.notifier).visibleNotes`; getter di Notifier bukan sumber reaktif. Perilaku tidak konsisten saat mengetik | **DITERIMA & DIPERBAIKI** — diganti `visibleNotesProvider` (Provider turunan yang di-`ref.watch`) |
| R2 | "Widget test empty state hanya me-render `Text` statis ber-Key, bukan `NotesPage` nyata — tidak menguji apa-apa" | saran | ✅ Terbukti: test lama tidak memompa `NotesPage` | **DITERIMA & DIPERBAIKI** — test kini me-render `NotesPage` dengan override `FakeNotesNotifier` (3 notes) + `FakeAuthNotifier`, lalu `enterText` query tak-cocok dan mengassert empty state muncul |
| R3 | "`searchQuery` sebaiknya dibersihkan lewat `sanitizeInput` sebelum disimpan ke state agar konsisten dengan `filterByTitle`" | saran | ⚠️ Sebagian benar, tapi redundan: `filterByTitle` sudah men-`trim` query di dalamnya; men-trim lagi di state hanya duplikasi | **DITOLAK** — normalisasi cukup di satu titik (domain), menjaga single source of truth |

**Ringkasan review kedua:** 1 blocker-benar diperbaiki (R1), 1 saran-benar diperbaiki (R2), 1 saran ditolak beralasan (R3).

## 9. Bukti Mesin Hijau (dijalankan nyata di mesin ini)

```
flutter analyze   -> No issues found!
dart format --output=none --set-exit-if-changed . -> 0 changed (exit 0)
flutter test      -> 21/21 All tests passed! (15 lama + 6 baru)
```

Bukti lengkap: `../screenshots/bukti-01..04-*.txt`.
