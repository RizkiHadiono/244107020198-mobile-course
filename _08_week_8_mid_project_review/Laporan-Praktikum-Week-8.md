# Laporan Praktikum Week 8: Mid Project Review & Code Review

**Nama:** MOKHAMAD RIZKI HADIONO SINGGIH  
**NIM:** 244107020198  
**Kelas:** TI-3G - Pemrograman Mobile  

---

## 1. Praktikum 1: Audit Git & Perbaikan Pesan Commit
Pada praktikum pertama, dilakukan audit menyeluruh terhadap riwayat Git repository portfolio. Objek yang direview adalah project Week 7 (`_07_week_7_clean_architecture/`, hasil refactor Clean Architecture dari Week 5–6).

* **Perintah Audit:** `git log --oneline -15`, `git branch -a`, dan `git status` dijalankan di root repository. Output lengkap tersimpan di [screenshots/bukti-06-audit-git.txt](screenshots/bukti-06-audit-git.txt).
* **Lima Masalah Ditemukan:**

| # | Temuan Audit | Bukti |
| :--- | :--- | :--- |
| 1 | Hanya ada branch `main` — belum ada `develop` sebagai target default PR | `git branch -a` → hanya `main` & `origin/main` |
| 2 | Seluruh commit dilakukan langsung ke `main` (tidak ada `feature/*` / `fix/*`) | 15 commit terakhir semuanya di `main` |
| 3 | Pesan commit non-konvensional: `AI Challenge`, `Mini project / Industry Challenge` | `git log --oneline` |
| 4 | Satu commit memuat banyak perubahan logis sekaligus | `git log --oneline` |
| 5 | Terdapat merge commit tidak terencana akibat kerja tanpa sinkronisasi disiplin | commit `61d3738` |

* **Perbaikan Pesan Commit (Simulasi):** Lima pesan commit lama ditulis ulang ke format konvensional `tipe(scope): deskripsi`, misalnya:
  - `AI Challenge` → `docs(week5): dokumentasikan prompt, evaluasi, dan verifikasi saran AI`
  - `Week 07 | Clean Architecture` → `refactor(arch): migrasi notes & auth ke Clean Architecture feature-first`
  - `Mini project / Industry Challenge` → `feat(notes): tambah indikator antrean sinkronisasi offline`
  - Tabel lengkap sebelum/sesudah beserta alasannya terdokumentasi di [docs/review-checklist.md](docs/review-checklist.md).

---

## 2. Praktikum 2: Code Review & Kategori Temuan
Pada praktikum kedua, dilakukan review terhadap PR project Week 7 dengan checklist wajib reviewer (kebenaran, edge case, arsitektur, test, keterbacaan).

* **Temuan Kebenaran (Error Path):** Jalur *update* catatan melewati validasi judul — `NotesNotifier.update()` memanggil `repo.updateNote()` langsung tanpa use case, sehingga aturan bisnis "judul tidak boleh kosong" dari `AddNote` bisa ditembus dari halaman edit. (**Diperbaiki**, lihat bagian 5).
* **Temuan Edge Case:** Fallback rute detail di `routes.dart` memfabrikasi `Note(title: 'Catatan #$id')` saat `state.extra == null` (deep-link/refresh web) — berpotensi menciptakan "catatan hantu". (**Dijadwalkan** sebagai issue #2).
* **Temuan Resource:** Dua `TextEditingController` di dialog tambah catatan tidak pernah di-`dispose()`. (**Dijadwalkan** sebagai issue #3).
* **Temuan Test:** Jalur `updateNote` sebelumnya tanpa test; `FakeNoteRepository` lama melempar `UnimplementedError`. (**Ditutup** oleh `test/update_note_test.dart` — 3 kasus baru).

---

## 3. Praktikum 3: Mesin Hijau, CI, dan Kesiapan Mid
Pada tahap ini, tiga pemeriksaan mesin dijalankan dan otomatisasi penolakan PR kotor dibuat.

* **Static Analysis:** `flutter analyze` → **No issues found!** (bukti: [screenshots/bukti-01-flutter-analyze.txt](screenshots/bukti-01-flutter-analyze.txt)).
* **Formatter:** Awalnya `dart format --set-exit-if-changed .` mengotori 14 file ([bukti SEBELUM](screenshots/bukti-03-dart-format-SEBELUM.txt)); setelah dirapikan, hasilnya **0 changed, exit 0** ([bukti SESUDAH](screenshots/bukti-04-dart-format-SESUDAH.txt)).
* **Automated Testing:** `flutter test` → **15/15 passed** (12 test lama + 3 test baru hasil tindak lanjut review) — bukti: [screenshots/bukti-02-flutter-test.txt](screenshots/bukti-02-flutter-test.txt).
* **Grep Sterilitas Arsitektur:** Tiga grep (presentation steril dari DB/jaringan, domain & core steril dari framework, model tidak bocor ke UI) seluruhnya **0 temuan** — bukti: [screenshots/bukti-05-grep-sterilitas.txt](screenshots/bukti-05-grep-sterilitas.txt).
* **CI Penolak PR Kotor:** Workflow `.github/workflows/ci.yml` dibuat untuk menjalankan analyze + format check + test pada setiap Pull Request.

```text
Analyzing _07_week_7_clean_architecture...
No issues found! (ran in 3.6s)

Formatted 27 files (0 changed) in 0.17 seconds.   exit code: 0

00:00 +15: All tests passed!
```

---

## 4. AI Challenge: Review AI vs Keputusan Final

Selama mengerjakan review ini, AI Coding Assistant difungsikan sebagai *reviewer awal*; keputusan final diambil setelah verifikasi bukti. Dokumentasi lengkap: [docs/ai-review-vs-keputusan.md](docs/ai-review-vs-keputusan.md).

### A. Prompt yang Digunakan
```text
Review PR Flutter ini sebagai senior Flutter dev.
Konteks: feature-first Clean Architecture (presentation -> domain <- data),
Riverpod, GoRouter, SQLite + Dio.
Fokus: kebenaran, arsitektur, dan test. Abaikan style.
Berikan 5 temuan teratas + level (blocker/saran)
+ alasan + usulan potongan kode perbaikan.
```

### B. Hasil & Evaluasi (5 Temuan Teratas AI)
1. **F1 [BLOCKER] — Jalur update melewati validasi judul.** Terbukti benar via `git grep "updateNote"` (`notes_providers.dart:105` memanggil repository langsung; tidak ada `update_note.dart` di domain). **DITERIMA & DIPERBAIKI** — aturan bisnis harus berlaku untuk SEMUA jalur mutasi.
2. **F2 [SARAN] — Fallback rute detail membuat "catatan hantu".** Terbukti benar (`routes.dart` baris 42–54 memfabrikasi Note; `parseIdFromPath` mati di produksi). **DITERIMA, DIJADWALKAN** (issue #2).
3. **F3 [SARAN] — Kebocoran `TextEditingController` di dialog tambah.** Terbukti benar (grep `dispose` hanya menemukan milik halaman detail). **DITERIMA, DIJADWALKAN** (issue #3).
4. **F4 [BLOCKER] — Klaim `presentation/providers` melanggar dependency rule.** Impor memang ada, tetapi klaim **salah**: providers adalah *composition root* (DI wiring) by design; dependency rule hanya melarang **domain** bergantung keluar (grep sterilitas domain/core = 0 temuan). **DITOLAK** — memindahkan wiring ke folder `di/` hanya memindahkan impor tanpa menutup risiko nyata.
5. **F5 [SARAN] — Ganti record result dengan `Either` (dartz) + hapus dead code.** Dead code terbukti (grep), tetapi usulan dartz **DITOLAK** karena menambah dependensi eksternal ke domain murni yang sudah teruji 15/15 dengan Dart 3 Records. Pembersihan dead code diterima sebagian sebagai chore terjadwal (issue #4).

### C. AI Verification Checklist & Keputusan Final

* **Apakah minimal 2 temuan AI terbukti benar dengan bukti?** Ya — F1, F2, F3 dibuktikan dengan grep, pembacaan jalur kode, dan reproduksi.
* **Apakah ada temuan yang ditolak dengan alasan tertulis?** Ya — F4 ditolak penuh (klaim pelanggaran dependency rule tidak valid pada composition root) dan F5 ditolak sebagian (dartz ditolak, dead code dijadwalkan).
* **Apakah cek dependency rule & nitpick style dilakukan per temuan?** Ya — setiap temuan diverifikasi terhadap aturan dependensi dan dipisahkan dari nitpick style (formatter ditangani terpisah via CI).

**Keputusan Final Penulis:**  
Keputusan diambil berdasarkan bukti (grep, jalur kode, eksekusi test) — bukan menempel mentah output AI. Blocker F1 ditindaklanjuti dengan use case `UpdateNote`; F4 dan F5-dartz ditolak karena bertentangan dengan keputusan arsitektur terdokumentasi dan menambah dependensi tanpa manfaat fungsional.

---

## 5. Refactoring Challenge & Testing
Temuan blocker F1 ditindaklanjuti sebagai unit PR kecil (< 100 baris):

* **Use Case `UpdateNote` Baru:** Memotong whitespace judul/isi dan menolak judul kosong dengan `ValidationFailure` — menyelaraskan jalur update dengan aturan bisnis `AddNote`.

```dart
class UpdateNote {
  const UpdateNote(this._repository);
  final NoteRepository _repository;
  Future<({bool success, Failure? failure})> call(Note note) async {
    final t = note.title.trim();
    if (t.isEmpty) return (success: false,
        failure: const ValidationFailure('Judul catatan tidak boleh kosong'));
    return _repository.updateNote(note.copyWith(title: t, body: note.body.trim()));
  }
}
```

* **Pengalihan Jalur:** `NotesNotifier.update()` dialihkan dari pemanggilan repository langsung ke use case `UpdateNote`.
* **Automated Testing:** Tiga unit test baru di `test/update_note_test.dart` (tolak judul kosong tanpa memanggil repository, trim whitespace sukses, failure repository diteruskan tanpa exception). Hasil akhir: **15/15 tests passed**.
* **Kebersihan Kode:** `dart format` dirapikan pada 14 file (murni whitespace, tanpa perubahan perilaku) dan CI kini menolak PR kotor secara otomatis.

---

## 6. Tugas Utama: Kesiapan Paruh Semester & Peta Issue/PR
Tugas akhir modul ini adalah memastikan project siap direview dan setiap temuan terpetakan menjadi issue/PR.

* **Aplikasi Berjalan Identik dengan Akhir Minggu 7 (Tanpa Regresi):** Satu-satunya perubahan perilaku adalah *fix* terreview — jalur update kini menolak judul kosong, selaras dengan aturan bisnis `AddNote`, dibuktikan oleh test.
* **Peta Issue / PR:**

| Item | Jenis | Status |
| :--- | :--- | :--- |
| #1 Edit catatan memungkinkan judul kosong | bug → PR `fix/update-note-validation` | Diperbaiki (use case `UpdateNote` + 3 test) |
| #2 Fallback rute detail membuat "catatan hantu" | saran (edge case deep-link) | Backlog |
| #3 Kebocoran TextEditingController di dialog tambah | saran (resource) | Backlog |
| #4 Hapus dead code `core/format.dart` | chore | Backlog |

* **Draft PR (Masalah → Solusi → Cara Uji)** dan langkah Git Flow (branch `develop`, commit `chore(format)` terpisah dari `fix(notes)`) disiapkan di [docs/draft-issue-pr.md](docs/draft-issue-pr.md).
* **Rencana Commit Tindak Lanjut:**
  1. `chore(format): terapkan dart format pada 14 berkas` (murni whitespace)
  2. `fix(notes): validasi judul kosong pada jalur update + test` (3 berkas: use case, provider, test)

**Bukti Mesin (dijalankan nyata, tersimpan sebagai berkas teks):**
* [screenshots/bukti-01-flutter-analyze.txt](screenshots/bukti-01-flutter-analyze.txt) — No issues found!
* [screenshots/bukti-02-flutter-test.txt](screenshots/bukti-02-flutter-test.txt) — 15/15 All tests passed!
* [screenshots/bukti-03-dart-format-SEBELUM.txt](screenshots/bukti-03-dart-format-SEBELUM.txt) — 14 file kotor
* [screenshots/bukti-04-dart-format-SESUDAH.txt](screenshots/bukti-04-dart-format-SESUDAH.txt) — 0 changed, exit 0
* [screenshots/bukti-05-grep-sterilitas.txt](screenshots/bukti-05-grep-sterilitas.txt) — 3 grep sterilitas, 0 temuan
* [screenshots/bukti-06-audit-git.txt](screenshots/bukti-06-audit-git.txt) — output audit git lengkap

---

## 7. Refleksi

1. **Apa bedanya "LGTM buta" dengan "approve bertanggung jawab"?**  
   Approve bertanggung jawab berarti reviewer menjalankan kode dan memverifikasi klaim — misalnya temuan F4 terbukti *salah* setelah dicek dengan grep dan dokumen arsitektur (providers adalah composition root yang sah). Sebaliknya, LGTM buta akan meneruskan bug seperti F1 (judul kosong tembus di jalur update) ke production dan mengikis kepercayaan tim.

2. **Kapan reviewer wajib "request changes" dan kapan cukup memberi saran?**  
   Request changes wajib untuk pelanggaran aturan bisnis/kebenaran yang bisa direproduksi (F1 — inkonsistensi validasi domain antar jalur mutasi). Saran cukup untuk perbaikan bernilai tetapi tidak memblokir (F2 deep-link edge case, F3 resource leak) — keduanya dijadwalkan sebagai issue backlog, bukan penghalang merge.

3. **Bagian mana dari review AI yang ditolak, dan mengapa?**  
   F4 (tuduhan pelanggaran dependency rule pada DI wiring providers) dan F5-dartz (menambah package `dartz` ke domain murni) ditolak. Keduanya bertentangan dengan keputusan arsitektur terdokumentasi Week 7 dan tidak memberi manfaat fungsional — domain sudah steril (grep = 0 temuan) dan Dart 3 Records sudah type-safe serta teruji 15/15.

4. **Perbaikan konkret apa yang dilakukan setelah review?**  
   Jalur update kini melewati use case domain `UpdateNote` dengan 3 unit test baru — aturan "judul tidak boleh kosong" berlaku konsisten di semua jalur mutasi (add maupun edit), dibuktikan hijau oleh mesin (`flutter test` 15/15, `flutter analyze` bersih, `dart format` exit 0).
