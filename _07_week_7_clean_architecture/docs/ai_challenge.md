# Dokumentasi AI Challenge: Evaluasi Clean Architecture & Trade-Off Arsitektur

**Mata Kuliah:** Pemrograman Mobile  
**Modul:** Minggu 07 - Clean Architecture  
**Nama Mahasiswa:** MOKHAMAD RIZKI HADIONO SINGGIH  
**NIM:** 244107020198  
**Kelas:** TI-3G  

---

## 1. Prompt AI Challenge
Berikut adalah prompt tantangan arsitektur yang diajukan ke AI Coding Assistant:

```text
Project Flutter saya: campus_notify (auth + FCM + daftar pengumuman) dan week5_offline_notes.
Kondisi kini: folder lib/{data, providers, pages, messaging},
repository tercampur dengan implementasi, widget memanggil Dio langsung atau query database manual.
Tugas:
1. Usulkan struktur feature-first Clean Architecture (presentation/domain/data) untuk fitur auth + notes / announcements.
2. Untuk tiap file lama, sebutkan tujuan barunya (pindah/pecah/hapus).
3. Tandai bagian yang over-engineering bila diterapkan ke CRUD sederhana, dan kapan use case benar-benar dibutuhkan vs repository langsung.
4. Tunjukkan wiring DI dengan Riverpod (tanpa package DI tambahan).
Jelaskan trade-off setiap keputusan.
```

---

## 2. Output Awal AI Assistant

### A. Rekomendasi Struktur Folder (Feature-First)
```text
lib/
├── core/
│   ├── failures.dart
│   └── format.dart
├── features/
│   ├── notes/
│   │   ├── domain/
│   │   │   ├── entities/note.dart
│   │   │   ├── repositories/note_repository.dart
│   │   │   └── usecases/
│   │   │       ├── get_notes.dart
│   │   │       ├── add_note.dart
│   │   │       ├── update_note.dart
│   │   │       ├── delete_note.dart
│   │   │       └── sync_notes.dart
│   │   ├── data/
│   │   │   ├── datasources/notes_database.dart
│   │   │   ├── models/note_model.dart
│   │   │   └── repositories/note_repository_impl.dart
│   │   └── presentation/
│   │       ├── providers/notes_providers.dart
│   │       └── pages/notes_page.dart
│   └── auth/
│       ├── domain/
│       │   ├── entities/user.dart
│       │   ├── repositories/auth_repository.dart
│       │   └── usecases/login_user.dart
│       ├── data/
│       │   ├── models/user_model.dart
│       │   └── repositories/auth_repository_impl.dart
│       └── presentation/
│           ├── providers/auth_providers.dart
│           └── pages/login_page.dart
└── routes.dart
```

### B. Pemetaan File Lama ke Struktur Baru
1. `lib/data/local/note.dart` (campuran Entity & Model) ➔ **Dipecah** menjadi `domain/entities/note.dart` (murni atribut bisnis tanpa toMap/fromMap) dan `data/models/note_model.dart` (turunan Note dengan toMap/fromMap/fromEntity).
2. `lib/data/repositories/note_repository.dart` ➔ **Dipecah** menjadi interface murni `domain/repositories/note_repository.dart` dan implementasi teknis `data/repositories/note_repository_impl.dart`.
3. `lib/data/local/db.dart` ➔ **Dipindah** ke `data/datasources/notes_database.dart` (hanya diakses oleh repository impl).
4. `lib/pages/notes_page.dart` & `note_detail_page.dart` ➔ **Dipindah & Direfactor** ke `presentation/pages/`, membuang query database langsung dan formatting tanggal mentah, diganti dengan memanggil `notesNotifierProvider` dan `core/format.dart`.
5. `lib/data/auth_repository.dart` ➔ **Dipecah** menjadi abstraksi `domain/repositories/auth_repository.dart` dan implementasi penyimpanan sesi `data/repositories/auth_repository_impl.dart`.

---

## 3. Evaluasi Kritis: Kapan Use Case Dibutuhkan vs Over-Engineering?

AI mengusulkan pembuatan file Use Case untuk **setiap operasi tunggal**:
* `GetNotes`
* `AddNote`
* `UpdateNote`
* `DeleteNote`
* `SyncNotes`

### Penilaian & Kritik Mahasiswa:
1. **Analisis Over-Engineering:**
   * Untuk operasi CRUD 1-baris tanpa aturan bisnis (seperti `deleteNote(id)` atau `updateNote(note)` yang hanya memanggil `repo.delete(id)`), pembuatan use case terpisah (misal `DeleteNoteUseCase`) adalah **over-engineering** dan menambah *mental overhead* serta *boilerplate* file kosong tanpa nilai tambah nyata bagi tim developer kecil.
2. **Kapan Use Case Benar-Benar Wajib:**
   * **Adanya Validasi / Aturan Bisnis (Business Rule):** Misalnya `AddNote` dan `LoginUser` yang melakukan pemangkasan whitespace, memeriksa panjang minimal judul/kata sandi, atau format email sebelum menyentuh repository.
   * **Orkestrasi > 1 Repository:** Misalnya fitur checkout yang perlu memanggil `CartRepository`, `PaymentRepository`, dan `StockRepository`.
   * **Transformasi Data / Failure Mapping:** Menyaring atau menyusun ulang entitas bisnis independen dari framework UI.
3. **Keputusan Kompromi:**
   * Operasi dengan aturan bisnis dibuatkan Use Case eksplisit (`GetNotes`, `AddNote`, `LoginUser`, `LogoutUser`).
   * Operasi update & delete teknis sederhana diorkestrasi langsung dari `NotesNotifier` ke `NoteRepository` interface, sehingga kode tetap ramping tanpa melanggar Dependency Rule!

---

## 4. Tabel Perbandingan: Usulan AI vs Keputusan Final

| Aspek Arsitektur | Usulan Awal AI Assistant | Keputusan Final Penulis | Alasan Teknis & Justifikasi |
| :--- | :--- | :--- | :--- |
| **Lokasi Repository Interface** | Di dalam `features/notes/domain/repositories/` | **DITERIMA** | Menjaga prinsip Dependency Inversion (DIP). Domain mendikte kontrak; layer luar (data) tunduk pada domain. |
| **Granularitas Use Case** | 1 Use Case untuk setiap metode CRUD (termasuk delete dan count) | **DISEDERHANAKAN (Ditolak sebagian)** | Menghindari file berlebih (*class explosion*). Use Case difokuskan pada operasi berlogika bisnis (`GetNotes`, `AddNote`, `LoginUser`). Operasi 1-baris langsung dipanggil oleh Notifier via repository. |
| **Struktur Entity & Model** | `NoteModel` berdiri sendiri dan memiliki duplikasi field dari `Note` | **DIREFACTOR** (`NoteModel extends Note`) | Memanfaatkan pewarisan OOP Dart agar model otomatis mewarisi field entity, sekaligus membatasi `toMap` dan `fromMap` murni di layer data. |
| **Error Handling (Failure)** | Melempar Exception standar atau dartz `Either` | **DIPILIH** Dart 3 Records + `sealed class Failure` | Fitur modern Dart 3 pattern matching record `({T data, Failure? failure})` lebih idiomatis, *type-safe*, dan tidak memerlukan dependensi eksternal seperti `dartz` / `fpdart`. |
| **Dependency Injection** | Riverpod Provider wiring | **DITERIMA** | Menyediakan DI terpusat tanpa reflection (*mirrors*) dan mudah di-override saat automated unit testing dengan Fake Repository. |
| **Ekstraksi Formatting** | Di dalam utility widget helper | **DIPINDAH** ke `lib/core/format.dart` | Fungsi murni (pure Dart) tanpa import Flutter memungkinkan pengujian unit test kilat tanpa overhead `testWidgets`. |

---

## 5. Hasil Tiga Verifikasi Grep Sterilitas

Berdasarkan aturan ketat Clean Architecture:
1. **Presentation Steril dari Data Mentah:**
   ```bash
   git grep -n -E "Dio\(|openDatabase|getDatabasesPath|FlutterSecureStorage|SharedPreferences\.getInstance|jsonDecode" -- "lib/features/*/presentation" "lib/pages"
   # HASIL: 0 matches (Steril 100%)
   ```
2. **Domain & Core Steril dari Framework & Package Luar:**
   ```bash
   git grep -n -E "import 'package:flutter|import 'package:dio|import 'package:sqflite|import 'package:firebase" -- "lib/features/*/domain" "lib/core"
   # HASIL: 0 matches (Steril 100%, Murni Dart)
   ```
3. **Static Analysis & Automated Unit Test:**
   ```bash
   flutter analyze  # Output: No issues found!
   flutter test     # Output: All 12 tests passed!
   ```
