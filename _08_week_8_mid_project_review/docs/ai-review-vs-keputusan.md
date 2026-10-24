# AI Review vs Keputusan Final — Week 8

Dokumen ini memenuhi **AI Prompt Challenge** dan **AI Verification Checklist** codelab Week 8.
Peran AI di sini: *reviewer awal*; keputusan final diambil mahasiswa setelah verifikasi bukti.

**Objek:** project `_07_week_7_clean_architecture/` (Flutter, feature-first Clean Architecture, Riverpod, GoRouter, SQLite).

---

## 1. Prompt yang Digunakan (sesuai codelab)

```
Review PR Flutter ini sebagai senior Flutter dev.
Konteks: feature-first Clean Architecture (presentation -> domain <- data),
Riverpod, GoRouter, SQLite + Dio.
Fokus: kebenaran, arsitektur, dan test. Abaikan style.
Berikan 5 temuan teratas + level (blocker/saran)
+ alasan + usulan potongan kode perbaikan.
```

## 2. Output Awal AI (5 Temuan Teratas)

> **F1 — [BLOCKER] Jalur update melewati validasi judul (kebenaran + arsitektur).**
> `AddNote` menolak judul kosong, tetapi `NotesNotifier.update()` memanggil `repo.updateNote()` langsung tanpa use case — aturan bisnis "judul tidak boleh kosong" bisa ditembus dari halaman edit. Inkonsistensi domain.
> Usulan kode:
> ```dart
> class UpdateNote {
>   const UpdateNote(this._repository);
>   final NoteRepository _repository;
>   Future<({bool success, Failure? failure})> call(Note note) async {
>     final t = note.title.trim();
>     if (t.isEmpty) return (success: false,
>         failure: const ValidationFailure('Judul catatan tidak boleh kosong'));
>     return _repository.updateNote(note.copyWith(title: t, body: note.body.trim()));
>   }
> }
> ```

> **F2 — [SARAN] Fallback rute detail membuat "catatan hantu" (kebenaran, edge case).**
> `routes.dart` memfabrikasi `Note(title: 'Catatan #$id')` ketika `state.extra == null` (deep-link / refresh web). Menyimpan catatan hantu ini memicu update ke id yang belum tentu ada. Fungsi `parseIdFromPath` di `core/format.dart` sudah disiapkan untuk kasus ini tetapi tidak dipakai.
> Usulan: muat catatan dari repository berdasarkan id hasil `parseIdFromPath`, atau redirect ke `/notes` bila data tidak ada.

> **F3 — [SARAN] Kebocoran `TextEditingController` di dialog tambah catatan (kebenaran, resource).**
> `_showAddNoteDialog` di `notes_page.dart` membuat dua `TextEditingController` tanpa `dispose()` — kebocoran resource kecil setiap dialog dibuka.
> Usulan: ekstrak dialog menjadi `StatefulWidget` sendiri dan dispose controller di `dispose()`.

> **F4 — [BLOCKER] `presentation/providers` mengimpor data layer (klaim pelanggaran dependency rule).**
> `notes_providers.dart` mengimpor `../../data/datasources/notes_database.dart` dan `../../data/repositories/note_repository_impl.dart`. AI menilai ini pelanggaran dependency rule dan mengusulkan memindahkan seluruh wiring ke layer `di/` terpisah.
> Usulan AI: buat `lib/di/providers.dart` baru.

> **F5 — [SARAN] Ganti record result dengan `Either` (dartz) + hapus fungsi `core/format.dart` yang tidak terpakai.**
> AI menilai record `(note, failure)` "kurang idiomatis" dan mengusulkan package dartz; juga menemukan `formatDateShort`, `sanitizeInput`, `parseIdFromPath` tidak dipakai kode produksi.
> Usulan AI: tambah dependensi dartz, refactor semua use case, hapus fungsi mati.

## 3. Tabel Verifikasi & Keputusan (AI Verification Checklist)

| # | Temuan benar-benar ada? (bukti) | Melanggar dependency rule? | Nitpick style? | Keputusan | Alasan teknis |
|---|---|---|---|---|---|
| F1 | ✅ YA — `git grep "updateNote"` membuktikan `notes_providers.dart:105` memanggil `repo.updateNote()` langsung; tidak ada berkas `domain/usecases/update_note.dart`; `note_detail_page.dart` mengirim judul mentah dari controller | Tidak (justru memperkuat domain) | Bukan | **DITERIMA & DIPERBAIKI** | Aturan bisnis harus hidup di domain untuk SEMUA jalur mutasi, bukan hanya add |
| F2 | ✅ YA — `routes.dart` baris 42–54 memfabrikasi Note; `git grep parseIdFromPath` → hanya muncul di `lib/core/format.dart` dan `test/` (mati di produksi) | Tidak | Bukan | **DITERIMA, DIJADWALKAN** (issue #2) | Perlu perubahan rute + pengambilan data by-id; di luar unit PR kecil minggu ini |
| F3 | ✅ YA — `notes_page.dart` `_showAddNoteDialog` membuat 2 controller, tidak ada `dispose()` (grep `dispose` di file hanya milik halaman detail) | Tidak | Bukan | **DITERIMA, DIJADWALKAN** (issue #3) | Perlu ekstraksi dialog ke StatefulWidget; perubahan UI terpisah dari fix domain |
| F4 | ⚠️ IMPOR ADA, KLAIM SALAH — grep membuktikan impor ada, tetapi: (1) README Week 7 mendokumentasikan providers sebagai "Notifier & **DI wiring**" (composition root) by design; (2) dependency rule hanya melarang **domain** bergantung keluar — grep sterilitas domain/core = 0 temuan; (3) tidak ada pemakaian API data langsung di widget | **Tidak melanggar** | Bukan | **DITOLAK** | Composition root merangkai implementasi adalah pola sah; memindahkan ke `di/` hanya memindahkan impor tanpa menutup risiko nyata; menambah layer baru = kompleksitas tanpa manfaat |
| F5 | ⚠️ SEBAGIAN — dead code terbukti (grep), tetapi usulan dartz: menambah dependensi eksternal ke **domain murni** yang saat ini "zero framework" dan sudah teruji 15/15 dengan record | Ya (dartz masuk domain) | Ya (motivasi utama = "idiomatis") | **DITOLAK** untuk dartz; **DITERIMA SEBAGIAN** untuk pembersihan dead code (chore terjadwal, issue #4) | Record result sudah cukup, type-safe, dan teruji; manfaat fungsional dartz nol di skala project ini. Dead code dihapus terpisah agar tidak mencampur refactor dengan fix |

**Ringkasan kepatuhan checklist:**
- ✅ Minimal 2 temuan AI terbukti benar dengan bukti → **F1, F2, F3** (bukti grep + jalur kode + reproduksi).
- ✅ Minimal 1 temuan ditolak dengan alasan tertulis → **F4** (ditolak penuh) dan **F5** (ditolak sebagian).
- ✅ Cek dependency rule & nitpick style dilakukan per temuan.

## 4. Pemetaan ke Kategori Wajib Review (Praktikum 2, Langkah 2)

| Kategori wajib reviewer | Dipenuhi oleh |
|---|---|
| 2 temuan kebenaran (null/state/error path/edge case) | F1 (error path update), F3 (resource leak) |
| 1 temuan edge case tambahan | F2 (deep-link/refresh web) |
| 1 temuan arsitektur | F4 (diverifikasi → ditolak beralasan) |
| 1 temuan test (kasus sukses/gagal kurang) | Jalur `updateNote` sebelumnya tanpa test; `FakeNoteRepository` lama melempar `UnimplementedError` → ditutup oleh `test/update_note_test.dart` (3 kasus: tolak judul kosong, trim sukses, failure repository) |
| 1 saran keterbacaan | Semantik `copyWith(errorMessage:)` di `NotesState`/`AuthState` menghapus error bila argumen tidak diisi — didokumentasikan sebagai catatan keterbacaan (konvensi "selalu isi eksplisit" dipertahankan konsisten) |

## 5. Tindak Lanjut & Status

| Temuan | Tindak lanjut | Status |
|---|---|---|
| F1 | Use case `UpdateNote` dibuat, `NotesNotifier.update()` dialihkan ke use case, 3 unit test baru | ✅ **Diterapkan** — `flutter test` 15/15, `flutter analyze` bersih |
| Temuan style (formatter) | `dart format` dirapikan (14 file) + CI `.github/workflows/ci.yml` menolak PR kotor | ✅ **Diterapkan** — format check kini exit 0 |
| F2 | Draft issue #2: muat detail catatan by-id / redirect, pakai `parseIdFromPath` | 📝 Backlog |
| F3 | Draft issue #3: ekstrak dialog tambah catatan ke StatefulWidget + dispose | 📝 Backlog |
| F4 | Tidak ada perubahan; keputusan & alasan terdokumentasi di sini | ❌ Ditolak |
| F5 (dead code) | Draft issue #4 (chore): hapus `formatDateShort`, `sanitizeInput` atau pakai `parseIdFromPath` pada fix F2 | 📝 Backlog |

## 6. Pernyataan Keputusan Final

Keputusan final diambil mahasiswa setelah verifikasi bukti (grep, pembacaan jalur kode, dan eksekusi test) — **bukan** dengan menempel mentah output AI. Dua klaim AI (F4, F5-dartz) ditolak karena bertentangan dengan keputusan arsitektur terdokumentasi dan/atau menambah dependensi tanpa manfaat fungsional. Saat demo, setiap temuan di atas dapat dijelaskan beserta buktinya tanpa membuka catatan AI.
