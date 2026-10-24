# Laporan Praktikum Week 9: AI-Assisted Development (Vibe Coding)

**Nama:** MOKHAMAD RIZKI HADIONO SINGGIH  
**NIM:** 244107020198  
**Kelas:** TI-3G - Pemrograman Mobile  

---

## 1. Praktikum 1: Perancangan Prompt (Formula 5 Slot)
Pada praktikum pertama, dirancang prompt berkualitas tinggi sebelum meminta AI menulis kode. Week 9 menambahkan **satu fitur kecil** ke project Week 7 yang sudah lolos review — bukan membuat project baru. Fitur yang ditambahkan: **pencarian judul catatan (search) + empty state**.

* **Prompt Inti (disimpan mentah):**

```text
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

* **Konteks yang Ditempel ke AI:** isi `note.dart` (entity), `notes_providers.dart` (Notifier & state), dan `pubspec.yaml` (versi package). **Tidak** ada token/secret yang ditempel (auth project ini simulasi lokal).
* Slot *Batas* ("jangan panggil SQLite dari widget") terbukti paling krusial — mencegah AI menghasilkan kode lintas layer sejak awal.

---

## 2. Praktikum 2: Generate, Verifikasi, dan Perburuan Halusinasi
Pada praktikum kedua, output AI diverifikasi dengan 6 langkah wajib (baca tiap baris → cek import → cek API nyata → analyze → test → uji manual) sebelum satu baris pun dipercaya.

* **Tiga Halusinasi/Bug AI yang Terbukti:**

| # | Temuan | Cara Membuktikan | Status |
| :--- | :--- | :--- | :--- |
| **H1** | **Logika yakin-tapi-salah:** filter case-sensitive `'Belajar'.contains('belajar')` → false, sehingga query huruf kecil tidak menemukan judul huruf besar | Test merah: `search('belajar')` pada data `Belajar Clean Architecture` mengembalikan 0, padahal harusnya 1. Diperbaiki dengan `toLowerCase()` di kedua sisi → test hijau | Terbukti & diperbaiki |
| **H2** | **Method/provider fiktif:** AI memakai `notesProvider` yang tidak ada di kode | `git grep "notesProvider"` → tidak ada kecocokan; yang tersedia `notesNotifierProvider`. Diperbaiki dengan merujuk provider nyata | Terbukti & diperbaiki |
| **H3** | **Saran berbahaya:** filter via `LIKE '%$q%'` langsung ke SQLite dari layer UI → rawan *SQL injection* & melanggar dependency rule | Dependency rule Week 7 melarang domain/UI menyentuh SQL; filter daftar kecil cukup di memori | Ditolak beralasan |

* **Tabel Usulan AI vs Keputusan:**

| Usulan AI | Keputusan | Alasan Teknis |
| :--- | :--- | :--- |
| `filterNotes` case-sensitive di widget | **Tolak + tulis manual** → pindahkan ke `core/format.dart` sebagai `filterByTitle` generik + `toLowerCase()` | Aturan filter adalah logika bisnis → wajib di domain agar bisa diunit-test tanpa widget |
| Panggil `notesProvider.notifier` | **Tolak + tulis manual** → gunakan `notesNotifierProvider` + `SearchNotes` use case | Provider yang disebut AI tidak ada (H2) |
| Filter via SQL `LIKE` di UI | **Tolak** | Melanggar dependency rule + risiko injection (H3); daftar notes kecil, filter in-memory cukup |
| Tambah use case `SearchNotes` murni Dart | **Terima + refactor** | Sejalan dependency rule; ditempatkan di `domain/usecases/` |
| Empty state terpisah "tidak cocok" vs "belum ada" | **Terima + refactor** | UX lebih jelas; ditandai `Key('notesSearchEmptyState')` agar testable |

---

## 3. Praktikum 3: Implementasi Fitur Search + Empty State
Pada tahap ini, fitur diimplementasikan penuh ke project Week 7 dengan tetap mematuhi dependency rule.

* **Search Judul Real-Time:** Search bar di atas daftar catatan; query disimpan di state dan daftar terfilter dihitung ulang secara reaktif.
* **Case-Insensitive:** Query `belajar` menemukan `Belajar Clean Architecture` (perbaikan H1).
* **Empty State Ganda:** Pesan berbeda untuk "belum ada catatan" vs "tidak ada catatan yang cocok".
* **Filter di Domain, Bukan Widget:** Aturan filter hidup di use case murni `SearchNotes` (mematuhi dependency rule; dapat diuji tanpa rendering).
* **Keputusan Final per File:**

| File | Keputusan |
| :--- | :--- |
| `lib/core/format.dart` | **Terima + refactor** — tambah `filterByTitle` generik (memakai `sanitizeInput` yang sebelumnya dead code) |
| `lib/features/notes/domain/usecases/search_notes.dart` | **Terima** — use case murni baru |
| `lib/features/notes/presentation/providers/notes_providers.dart` | **Terima + refactor** — tambah `searchNotesProvider`, `searchQuery` di state, `setSearchQuery`, dan `visibleNotesProvider` (Provider turunan reaktif) |
| `lib/features/notes/presentation/pages/notes_page.dart` | **Terima + refactor** — `NotesPage` jadi `ConsumerStatefulWidget` agar `_searchController` di-`dispose()` (sekaligus menutup temuan F3 Week 8), tambah search bar + empty state |
| `test/search_filter_test.dart` | **Terima** — 4 unit test (kosong/case-insensitive/sebagian-kata/tak-cocok) |
| `test/search_empty_state_test.dart` | **Terima** — 2 widget test empty state |

---

## 4. AI Challenge: Review Kedua & Verifikasi Keputusan
Setelah fitur selesai diimplementasi, kode search diminta direview ulang oleh AI sebagai senior dev (**prompt terpisah** dari prompt generate). Dokumentasi lengkap: [docs/ai-log.md](docs/ai-log.md).

### A. Prompt Review yang Digunakan
```text
Review kode search Flutter ini sebagai senior dev.
Konteks: feature-first (presentation->domain<-data), Riverpod, SQLite + Dio.
Fokus: kebenaran, arsitektur, test. Abaikan style.
Beri 3 temuan + level blocker/saran + alasan.
```

### B. Hasil Review & Verifikasi Mahasiswa

| # | Temuan AI | Level | Verifikasi (Bukti) | Keputusan |
| :--- | :--- | :--- | :--- | :--- |
| R1 | Getter `visibleNotes` dipanggil via `ref.read(notifier)` — **tidak reaktif**; UI bisa menampilkan daftar basi saat query berubah | blocker | Terbukti: getter di Notifier bukan sumber reaktif; perilaku tidak konsisten saat mengetik | **DITERIMA & DIPERBAIKI** — diganti `visibleNotesProvider` yang di-`ref.watch` |
| R2 | Widget test empty state hanya me-render `Text` statis ber-Key, bukan `NotesPage` nyata | saran | Terbukti: test lama tidak memompa `NotesPage` | **DITERIMA & DIPERBAIKI** — test kini me-render `NotesPage` dengan override `FakeNotesNotifier` + `FakeAuthNotifier` |
| R3 | `searchQuery` sebaiknya di-`sanitizeInput` sebelum disimpan ke state | saran | Redundan: `filterByTitle` sudah men-`trim` query di dalamnya; men-trim lagi di state hanya duplikasi | **DITOLAK** — normalisasi cukup di satu titik (domain), menjaga single source of truth |

### C. AI Verification Checklist & Keputusan Final

* **Apakah ada temuan blocker dari review yang terbukti benar?** Ya — R1 terbukti (getter non-reaktif) dan diperbaiki menjadi Provider turunan reaktif.
* **Apakah ada saran yang ditolak dengan alasan tertulis?** Ya — R3 ditolak karena menduplikasi normalisasi yang sudah terjadi di domain.
* **Apakah seluruh klaim AI diverifikasi mesin sebelum diterima?** Ya — setiap klaim diuji dengan grep, analyze, dan test; ringkasannya: 1 blocker-benar diperbaiki (R1), 1 saran-benar diperbaiki (R2), 1 saran ditolak beralasan (R3).

**Keputusan Final Penulis:**  
Dari total 8 usulan AI sepanjang siklus (generate + review), keputusan akhir: **1 diterima murni, 5 diterima + direfactor, 2 ditolak + ditulis manual** — semua beralasan teknis dan dibuktikan mesin, bukan diterima mentah.

---

## 5. Refactoring Challenge & Testing
Kode hasil generate AI tidak langsung dipakai — dirapikan terlebih dahulu agar memenuhi standar arsitektur:

* **Filter Dipindah dari Widget ke Domain:** Fungsi filter yang semula diusulkan AI di dalam widget dipindah ke use case domain murni `SearchNotes` + fungsi generik `filterByTitle` di `core/format.dart`, sehingga dapat diuji tanpa rendering.
* **Fungsi Dipecah Kecil:** Semua fungsi < 40 baris; tidak ada import lintas layer (grep sterilitas tetap 0 temuan).
* **Reaktivitas Diperbaiki:** Daftar terfilter kini dihitung oleh `visibleNotesProvider` (Provider turunan yang di-`ref.watch`), menggantikan getter non-reaktif.
* **Resource Aman:** `NotesPage` menjadi `ConsumerStatefulWidget` agar `_searchController` di-`dispose()` dengan benar.
* **Hasil Akhir Mesin:**

```text
flutter analyze   -> No issues found! (ran in 6.2s)
dart format --output=none --set-exit-if-changed . -> Formatted 30 files (0 changed), exit 0
flutter test      -> 21/21 All tests passed! (15 lama + 6 baru)
```

---

## 6. Tugas Utama: Fitur Search Terintegrasi & Bukti Mesin Hijau
Tugas akhir modul ini adalah fitur search yang terintegrasi penuh pada aplikasi catatan hasil refactor Week 7, dengan seluruh klaim dibuktikan oleh mesin.

* **Cara Menjalankan:**

```bash
cd _07_week_7_clean_architecture
flutter pub get
flutter test        # 21/21 passed (15 lama + 6 baru untuk search)
flutter analyze     # No issues found
flutter run         # jalankan aplikasi
```

* **Matriks Uji Fitur Search:**
  - Query kosong → seluruh catatan tampil.
  - Query cocok (case-insensitive) → daftar terfilter.
  - Query tak cocok → empty state "Tidak ada catatan yang cocok" muncul.
  - Daftar kosong total → empty state "Belum ada catatan" muncul.

**Bukti Mesin (dijalankan nyata, tersimpan sebagai berkas teks):**
* [screenshots/bukti-01-flutter-analyze.txt](screenshots/bukti-01-flutter-analyze.txt) — No issues found!
* [screenshots/bukti-02-flutter-test.txt](screenshots/bukti-02-flutter-test.txt) — 21/21 All tests passed!
* [screenshots/bukti-03-dart-format.txt](screenshots/bukti-03-dart-format.txt) — 0 changed, exit 0
* [screenshots/bukti-04-grep-sterilitas.txt](screenshots/bukti-04-grep-sterilitas.txt) — domain steril + `visibleNotesProvider` terpakai via `ref.watch` + getter lama hilang

---

## 7. Refleksi

1. **Halusinasi apa yang ditemukan, dan bagaimana membuktikannya?**  
   Yang paling halus adalah H1 — filter yang *tampak* benar tetapi case-sensitive, hanya terbukti lewat satu test kecil yang gagal (`search('belajar')` mengembalikan 0 padahal harusnya 1). Selain itu H2 (provider fiktif `notesProvider`) dibuktikan dengan grep. Ini menegaskan prinsip: **klaim AI adalah hipotesis sampai ada bukti**.

2. **Prompt seperti apa yang paling membantu?**  
   Formula 5 slot — terutama slot *Batas* ("jangan panggil SQLite dari widget", "domain tetap murni Dart") — mencegah AI menghasilkan kode lintas layer sejak awal. Menempel konteks nyata (entity, provider, versi package di pubspec) mengurangi tebakan API fiktif.

3. **Bagian mana dari kode AI yang direfactor, dan mengapa?**  
   Filter dipindah dari widget ke use case domain murni `SearchNotes` — membuatnya testable tanpa rendering dan mematuhi dependency rule. Selain itu getter non-reaktif diganti `visibleNotesProvider`, dan `NotesPage` diubah menjadi `ConsumerStatefulWidget` agar controller teks di-`dispose()` dengan benar.

4. **Keputusan tersulit apa yang diambil terhadap saran AI?**  
   Menolak saran "optimasi" SQL `LIKE` (H3) — terlihat efisien, tetapi melanggar arsitektur (UI menyentuh SQL langsung) dan membuka celah *SQL injection*. Dipilih filter in-memory yang aman, sesuai dependency rule, dan sudah cukup cepat untuk daftar catatan skala lokal.
