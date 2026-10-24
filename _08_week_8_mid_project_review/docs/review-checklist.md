# Review Checklist — Week 8 (Mid Project Review & Code Review)

**Nama:** MOKHAMAD RIZKI HADIONO SINGGIH · **NIM:** 244107020198 · **Kelas:** TI-3G
**Objek review:** project Week 7 — `_07_week_7_clean_architecture/` (hasil refactor Clean Architecture dari Week 5–6)

---

## 1. Audit Riwayat Git (Praktikum 1, Langkah 1)

Perintah yang dijalankan di root repository (output lengkap: `../screenshots/bukti-06-audit-git.txt`):

```bash
git log --oneline -15
git branch -a
git status
```

### Masalah yang ditemukan

| # | Temuan Audit | Bukti |
|---|---|---|
| 1 | Hanya ada branch `main` — belum ada `develop` sebagai target default PR | `git branch -a` → hanya `main` & `origin/main` |
| 2 | Seluruh commit dilakukan langsung ke `main` (tidak ada `feature/*` / `fix/*`) | `git log` 15 commit terakhir semuanya di `main` |
| 3 | Pesan commit non-konvensional: `AI Challenge`, `Mini project / Industry Challenge`, `Week 07 \| Clean Architecture` | `git log --oneline` |
| 4 | Satu commit memuat banyak perubahan logis: `Praktikum 1: SharedPreference, Praktikum 2: SQLite..., Praktikum 3: Cache-first...` | `git log --oneline` |
| 5 | Terdapat merge commit tidak terencana (`Merge branch 'main' of ...`) akibat kerja tanpa sinkronisasi disiplin | commit `61d3738` |

## 2. Perbaikan Pesan Commit (Praktikum 1, Langkah 3 — Simulasi)

Tabel sebelum/sesudah — 5 pesan commit lama ditulis ulang ke format konvensional `tipe(scope): deskripsi`:

| Sebelum (asli di log) | Sesudah (konvensional) | Alasan |
|---|---|---|
| `AI Challenge` | `docs(week5): dokumentasikan prompt, evaluasi, dan verifikasi saran AI` | Tipe `docs` jelas ini bukan kode; scope dan isi langsung terbaca |
| `Refactoring, testing, dan error umum` | dipecah → `refactor(notes): pisahkan repository catatan dari UI` + `test(notes): tambah unit test use case` | Satu commit = satu perubahan logis; refactor dan test tidak boleh digabung agar mudah di-review/di-revert |
| `Week 07 \| Clean Architecture` | `refactor(arch): migrasi notes & auth ke Clean Architecture feature-first` | Menyebut apa yang berubah dan ruang lingkupnya, bukan sekadar label minggu |
| `Mini project / Industry Challenge` | `feat(notes): tambah indikator antrean sinkronisasi offline` | `feat` menjelaskan fitur yang dihasilkan, bukan nama tugas kuliah |
| `Praktikum 1: SharedPreference, Praktikum 2: ..., Praktikum 3: ...` | dipecah → `feat(storage): penyimpanan preferensi dengan SharedPreferences`, `feat(notes): repository catatan berbasis SQLite`, `feat(sync): cache-first dan antrean sinkronisasi` | Tiga perubahan logis wajib tiga commit agar tiap commit bisa direview dan di-revert terpisah |

## 3. Checklist Kesiapan Tengah Semester (Praktikum 3, Langkah 3)

| Kriteria | Status | Bukti |
|---|---|---|
| Struktur feature-first terbukti (3 grep sterilitas) | ✅ 0 temuan | `../screenshots/bukti-05-grep-sterilitas.txt` |
| `flutter analyze` bersih | ✅ No issues found | `../screenshots/bukti-01-flutter-analyze.txt` |
| `dart format --set-exit-if-changed .` bersih | ✅ (sebelumnya 14 file kotor → dirapikan, kini 0 changed) | `../screenshots/bukti-03-dart-format-SEBELUM.txt`, `../screenshots/bukti-04-dart-format-SESUDAH.txt` |
| `flutter test` hijau | ✅ 15/15 passed (12 lama + 3 baru hasil tindak lanjut review) | `../screenshots/bukti-02-flutter-test.txt` |
| Penolakan otomatis (CI) | ✅ `.github/workflows/ci.yml` dibuat (analyze + format + test) | root repo |
| PR kecil + commit jelas | 📝 Draft issue & PR siap — dieksekusi mahasiswa di GitHub | `draft-issue-pr.md` |
| Komentar review ditindaklanjuti | ✅ Blocker diperbaiki (`UpdateNote` use case + test); saran terdokumentasi sebagai issue backlog | `ai-review-vs-keputusan.md` |
| README + screenshot + cara menjalankan | ✅ | `../README.md`, folder `../screenshots/` |

## 4. Definisi Selesai — Pemetaan

| Syarat codelab | Status |
|---|---|
| Aplikasi berjalan identik dengan akhir Minggu 7 (tanpa regresi) | ✅ — satu-satunya perubahan perilaku adalah *fix* terreview: jalur update kini menolak judul kosong (selaras aturan bisnis `AddNote`), dibuktikan test |
| Tiga pemeriksaan mesin hijau | ✅ analyze + format + test |
| Minimal 1 PR kecil via review | 📝 perubahan sudah disiapkan sebagai unit PR kecil (< 100 baris: 1 use case baru, 1 edit provider, 1 file test) + template PR & issue; merge dilakukan mahasiswa |
| README memuat status paruh semester + peta issue/PR | ✅ `../README.md` |

> **Catatan tindak lanjut commit (untuk mahasiswa):** perubahan hasil Week 8 terdiri dari dua unit commit terpisah —
> 1. `chore(format): terapkan dart format pada 14 berkas` (murni whitespace, tanpa perubahan perilaku)
> 2. `fix(notes): validasi judul kosong pada jalur update + test` (berkas: `update_note.dart`, `notes_providers.dart`, `update_note_test.dart`)
