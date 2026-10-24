# Modul 08: Mid Project Review & Code Review

**Nama Mahasiswa:** MOKHAMAD RIZKI HADIONO SINGGIH
**NIM:** `244107020198`
**Kelas:** TI-3G - Pemrograman Mobile
**Program Studi:** D4 Teknik Informatika, Politeknik Negeri Malang

> Folder portfolio ini memenuhi deliverable codelab Week 8 (`08-week-8-mid-project-review/`): struktur `docs/`, `README.md`, dan `screenshots/`.

---

## 📌 Status Paruh Semester

Project yang direview: **`_07_week_7_clean_architecture/`** (kelanjutan Week 5 offline notes & Week 6 auth, hasil refactor Clean Architecture feature-first Week 7).

| Aspek | Status |
|---|---|
| Aplikasi berjalan identik dengan akhir Minggu 7 (tanpa regresi) | ✅ |
| `flutter analyze` | ✅ No issues found |
| `dart format --set-exit-if-changed .` | ✅ 0 changed (setelah 14 file dirapikan) |
| `flutter test` | ✅ **15/15 passed** (12 lama + 3 test baru hasil tindak lanjut review) |
| CI penolak PR kotor (`.github/workflows/ci.yml`) | ✅ dibuat |
| Audit git + perbaikan pesan commit | ✅ `docs/review-checklist.md` |
| Review AI + verifikasi keputusan | ✅ `docs/ai-review-vs-keputusan.md` (3 diterima berbukti, 2 ditolak beralasan) |
| Issue + PR kecil | 📝 draft siap pakai: `docs/draft-issue-pr.md` (eksekusi GitHub oleh mahasiswa) |

## 🗺️ Peta Issue / PR

| Item | Jenis | Status |
|---|---|---|
| #1 Edit catatan memungkinkan judul kosong | bug → PR `fix/update-note-validation` | ✅ diperbaiki (use case `UpdateNote` + 3 test) |
| #2 Fallback rute detail membuat "catatan hantu" | saran (edge case deep-link) | 📝 backlog |
| #3 Kebocoran TextEditingController di dialog tambah | saran (resource) | 📝 backlog |
| #4 Hapus dead code `core/format.dart` | chore | 📝 backlog |

## ✨ Fitur Utama Project (hasil Week 5–7)

1. **Catatan offline-first** berbasis SQLite dengan antrean sinkronisasi (flag `dirty`) dan indikator "Unsynced".
2. **Autentikasi lokal** dengan sesi SharedPreferences + route guard GoRouter (redirect login).
3. **Clean Architecture feature-first**: presentation → domain ← data; domain murni Dart (0 impor framework — terbukti grep).
4. **Validasi bisnis di use case**: `AddNote`, `LoginUser`, dan kini **`UpdateNote`** (hasil tindak lanjut review Week 8).

## 🛠️ Stack Teknologi

Flutter 3.47.6 · Dart 3.13.5 · Riverpod (Notifier) · GoRouter · sqflite · shared_preferences · dio · GitHub Actions (CI)

## 🚀 Cara Menjalankan

```bash
cd _07_week_7_clean_architecture
flutter pub get
flutter test        # 15/15 passed
flutter analyze     # No issues found
flutter run         # jalankan aplikasi
```

## ✅ Hasil yang Dicapai (Week 8)

1. **Audit git** terdokumentasi: 5 masalah ditemukan (tanpa `develop`, commit langsung ke `main`, pesan non-konvensional, commit campur, merge tak terencana) + tabel perbaikan 5 pesan commit → format konvensional.
2. **Mesin hijau berbukti**: formatter awalnya kotor (14 file) → dirapikan → analyze + format + test semua hijau; bukti tersimpan di `screenshots/`.
3. **Review AI terverifikasi**: 5 temuan (1 blocker-benar, 2 saran-benar, 1 blocker-ditolak, 1 saran-ditolak-sebagian) dengan bukti grep/test per temuan.
4. **Blocker ditindaklanjuti**: use case `UpdateNote` + 3 unit test (15/15 hijau) — perubahan < 100 baris, siap menjadi PR kecil.
5. **Otomatisasi**: workflow CI menjalankan analyze + format check + test pada setiap PR.

## 📂 Struktur Folder

```text
_08_week_8_mid_project_review/
├── README.md                        # berkas ini
├── docs/
│   ├── review-checklist.md          # audit git + tabel commit + kesiapan mid
│   ├── ai-review-vs-keputusan.md    # prompt, output AI, tabel verifikasi, keputusan final
│   └── draft-issue-pr.md            # langkah git flow + draft issue #1–#4 + template PR
└── screenshots/                     # bukti tekstual output mesin (dijalankan nyata di mesin ini)
    ├── bukti-01-flutter-analyze.txt
    ├── bukti-02-flutter-test.txt
    ├── bukti-03-dart-format-SEBELUM.txt
    ├── bukti-04-dart-format-SESUDAH.txt
    ├── bukti-05-grep-sterilitas.txt
    └── bukti-06-audit-git.txt
```

> Catatan: bukti berupa berkas teks hasil perintah nyata (24 Okt 2026). Tangkapan layar gambar (PR/issue GitHub) akan ditambahkan mahasiswa setelah eksekusi push & PR.

## 💭 Refleksi

- **LGTM buta vs approve bertanggung jawab:** approve bertanggung jawab berarti reviewer menjalankan kode dan memverifikasi klaim (mis. F4 terbukti salah setelah dicek grep + dokumen arsitektur); LGTM buta meneruskan bug seperti F1 ke production dan mengikis kepercayaan tim.
- **Kapan request changes vs saran:** request changes untuk pelanggaran aturan bisnis/kebenaran yang bisa direproduksi (F1); saran untuk perbaikan bernilai tapi tidak memblokir (F2, F3) — dijadwalkan sebagai issue, bukan penghalang merge.
- **Bagian review AI yang ditolak:** F4 (tuduhan pelanggaran dependency rule pada DI wiring) dan F5-dartz (menambah paket ke domain murni), karena keduanya bertentangan dengan keputusan arsitektur terdokumentasi dan tanpa manfaat fungsional.
- **Perbaikan konkret pasca-review:** jalur update kini melewati use case `UpdateNote` dengan 3 test — aturan "judul tidak boleh kosong" kini berlaku konsisten di semua jalur mutasi, dibuktikan hijau oleh mesin.
