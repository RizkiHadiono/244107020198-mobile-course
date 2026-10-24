# Draft Issue & Pull Request — Week 8

Semua artefak git/GitHub (branch, issue, PR, merge) **dieksekusi sendiri oleh mahasiswa**. Dokumen ini menyediakan draft siap pakai sesuai template codelab.

---

## 0. Langkah Git Flow (jalankan berurutan)

```bash
# Sekali saja: buat develop dari main (codelab: "jika develop belum ada, buat dari main sekali")
git checkout main
git checkout -b develop
git push -u origin develop
# Jadikan develop target default PR di GitHub: Settings -> Branches -> Default branch

# Commit 1: rapikan formatter (tanpa perubahan perilaku)
git add -p   # pilih hanya perubahan format
git commit -m "chore(format): terapkan dart format pada 14 berkas"

# Commit 2: perbaikan hasil review (PR utama)
git checkout -b fix/update-note-validation
git add _07_week_7_clean_architecture/lib/features/notes/domain/usecases/update_note.dart \
        _07_week_7_clean_architecture/lib/features/notes/presentation/providers/notes_providers.dart \
        _07_week_7_clean_architecture/test/update_note_test.dart
git commit -m "fix(notes): validasi judul kosong pada jalur update + test"
git push -u origin fix/update-note-validation

# Commit 3: CI + portfolio week 8
git add .github/workflows/ci.yml _08_week_8_mid_project_review/
git commit -m "ci(week8): workflow analyze+format+test dan dokumen mid review"
git push
```

---

## 1. Draft Issue #1 (bug — direproduksi dari temuan F1)

**Judul:** Edit catatan memungkinkan judul kosong (melewati aturan bisnis AddNote)

**Langkah reproduksi:**
1. Login, buka satu catatan (halaman detail).
2. Hapus seluruh isi field judul, isi field body bebas.
3. Tekan **Simpan Perubahan**.

**Hasil saat ini:** catatan tersimpan dengan judul kosong.
**Hasil diharapkan:** muncul error "Judul catatan tidak boleh kosong", data tidak berubah — sama seperti perilaku saat menambah catatan.

**Akar masalah:** `NotesNotifier.update()` memanggil `NoteRepository.updateNote()` langsung tanpa use case, sehingga validasi domain `AddNote` tidak berlaku pada jalur update.

---

## 2. Draft PR (template codelab — Masalah → Solusi → Cara uji)

```
Judul: fix(notes): validasi judul kosong pada jalur update + test

Masalah: pengguna bisa mengosongkan judul catatan lewat halaman edit,
meskipun penambahan catatan baru sudah divalidasi (issue #1).

Solusi: tambah use case domain UpdateNote (trim + tolak judul kosong
dengan ValidationFailure) dan alihkan NotesNotifier.update() dari
pemanggilan repository langsung ke use case tersebut.

Cara uji:
 1) edit catatan -> kosongkan judul -> error muncul, data tidak berubah.
 2) flutter test test/update_note_test.dart
 3) flutter analyze && dart format --output=none --set-exit-if-changed .

Ukuran: < 100 baris (1 use case baru, 1 edit provider, 1 file test = 3 kasus).

Closes #1
```

## 3. Draft Issue Backlog (temuan saran — dari review)

| Issue | Judul | Isi ringkas |
|---|---|---|
| #2 | Fallback rute detail membuat "catatan hantu" | `routes.dart` memfabrikasi `Note(title: 'Catatan #$id')` saat `state.extra == null` (deep-link/refresh web). Solusi: muat by-id dari repository memakai `parseIdFromPath` (saat ini dead code), atau redirect ke `/notes` |
| #3 | Kebocoran TextEditingController di dialog tambah catatan | `_showAddNoteDialog` membuat 2 controller tanpa `dispose()`. Solusi: ekstrak dialog menjadi StatefulWidget sendiri |
| #4 | (chore) Hapus dead code di `core/format.dart` | `formatDateShort` & `sanitizeInput` tidak dipakai kode produksi (hanya di test); `parseIdFromPath` dipakai kembali saat fix #2 |

## 4. Catatan Review

- Reviewer awal: AI (sesuai kebijakan codelab) — output, verifikasi, dan keputusan terdokumentasi penuh di `ai-review-vs-keputusan.md`.
- Hasil review PR utama: **Request changes → diperbaiki (UpdateNote + test) → layak approve** (analyze bersih, format bersih, 15/15 test hijau).
- Bila tersedia pasangan kelas, tukar PR ini untuk review sejawat 15 menit dengan checklist: 2 kebenaran, 1 arsitektur, 1 test, 1 keterbacaan.
