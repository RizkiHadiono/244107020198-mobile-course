# Modul 07: Clean Architecture (Feature-First)

**Nama Mahasiswa:** MOKHAMAD RIZKI HADIONO SINGGIH  
**NIM:** `244107020198`  
**Kelas:** TI-3G - Pemrograman Mobile  
**Program Studi:** D4 Teknik Informatika, Politeknik Negeri Malang  

---

## 📌 Ringkasan & Tujuan Praktikum
Pada modul ini, dilakukan refactoring komprehensif dari arsitektur monolitik/tercampur pada proyek sebelumnya (Minggu 5 & Minggu 6) ke dalam arsitektur **Clean Architecture dengan pendekatan Feature-First**.

Tujuan utama dari arsitektur ini adalah memisahkan tanggung jawab kode (*Separation of Concerns*) dan memastikan **Dependency Rule** (aturan dependensi hanya mengarah ke dalam, menuju domain inti bisnis) terpenuhi sepenuhnya.

---

## 🏛️ Diagram Arsitektur & Aturan Dependensi (Dependency Rule)

```text
+-------------------------------------------------------------------+
|                        PRESENTATION LAYER                         |
|   (Widgets, Pages, State Notifiers, Riverpod Providers, Routes)   |
+-------------------------------------------------------------------+
                                  |
                                  | bergantung ke (depends on)
                                  v
+-------------------------------------------------------------------+
|                           DOMAIN LAYER                            |
|       (Entities, Repository Interfaces, Use Cases, Failures)      |
|                      [MURNI DART - ZERO FRAMEWORK]                 |
+-------------------------------------------------------------------+
                                  ^
                                  | diimplementasikan oleh (implements)
+-------------------------------------------------------------------+
|                            DATA LAYER                             |
|    (Models, Repository Impl, SQLite Data Sources, SharedPreferences)  |
+-------------------------------------------------------------------+
```

### 🔁 Arah Panah Dependensi
* **Presentation ➔ Domain:** Presentation hanya membaca Entity murni dan memanggil Use Case atau Repository Interface melalui Riverpod Provider.
* **Data ➔ Domain:** Data Repository mengimplementasikan kontrak interface yang didefinisikan oleh Domain. Data Model mengonversi data SQLite/JSON ke Entity Domain.
* **Domain:** Tidak mengetahui dan tidak mengimpor apapun dari layer luar (Flutter, Sqflite, Dio, SharedPreferences, dsb).

---

## 📂 Struktur Direktori Proyek (Feature-First)

```text
lib/
├── core/
│   ├── failures.dart           # Hierarchy Failure domain (murni Dart)
│   └── format.dart             # Pure formatting (tanggal, parsing rute, sanitasi input)
├── features/
│   ├── notes/
│   │   ├── domain/
│   │   │   ├── entities/note.dart
│   │   │   ├── repositories/note_repository.dart     # Interface kontrak
│   │   │   └── usecases/
│   │   │       ├── get_notes.dart                    # Ambil daftar catatan
│   │   │       └── add_note.dart                     # Tambah catatan + validasi bisnis
│   │   ├── data/
│   │   │   ├── datasources/notes_database.dart       # SQLite database helper
│   │   │   ├── models/note_model.dart                # Mapping toMap & fromMap
│   │   │   └── repositories/note_repository_impl.dart# Implementasi kontrak
│   │   └── presentation/
│   │       ├── providers/notes_providers.dart        # Notifier & DI wiring
│   │       └── pages/
│   │           ├── notes_page.dart                   # Halaman list catatan
│   │           └── note_detail_page.dart             # Halaman edit & detail catatan
│   └── auth/
│       ├── domain/
│       │   ├── entities/user.dart
│       │   ├── repositories/auth_repository.dart     # Interface kontrak autentikasi
│       │   └── usecases/
│       │       ├── login_user.dart                   # Validasi kredensial & login
│       │       └── logout_user.dart                  # Keluar sesi
│       ├── data/
│       │   ├── models/user_model.dart                # Model serialisasi user
│       │   └── repositories/auth_repository_impl.dart# Simpan token & sesi lokal
│       └── presentation/
│           ├── providers/auth_providers.dart         # Auth Notifier & DI wiring
│           └── pages/login_page.dart                 # UI login modern
├── routes.dart                 # GoRouter & rute navigasi terpusat
└── main.dart                   # Entrypoint aplikasi dengan ProviderScope
test/
├── get_notes_test.dart         # Unit test GetNotes & AddNote dengan FakeNoteRepository
├── auth_test.dart              # Unit test LoginUser & LogoutUser dengan FakeAuthRepository
└── format_test.dart            # Unit test fungsi murni format.dart
docs/
└── ai_challenge.md             # Dokumentasi prompt, evaluasi AI, dan verifikasi
screenshots/                    # Dokumentasi tangkapan layar aplikasi
```

---

## ✨ Fitur Utama
1. **Pemisahan Entity vs Model:**
   * `Note` & `User` di Domain bersih dari metode serialisasi seperti `toMap()` dan `fromMap()`.
   * Serialisasi dan deserialisasi data dari SQLite/Storage hanya hidup di `NoteModel` dan `UserModel` pada Data layer.
2. **Repository Pattern dengan Dependency Inversion:**
   * Abstraksi interface diletakkan di `domain/repositories/`.
   * Implementasi konkrit diletakkan di `data/repositories/`.
3. **Use Case Berlogika Bisnis:**
   * `AddNote`: Memeriksa judul agar tidak kosong sebelum menghubungi repository.
   * `LoginUser`: Memvalidasi kelayakan email (memiliki `@`) dan panjang sandi minimal 6 karakter.
4. **Pure Formatting Function:**
   * Formatting tanggal dan parsing parameter rute diekstraksi ke `core/format.dart` sehingga dapat diuji secara kilat tanpa membutuhkan widget rendering.
5. **Testing Independen tanpa Database/Jaringan:**
   * Seluruh domain diuji menggunakan `FakeNoteRepository` dan `FakeAuthRepository` tanpa menyentuh SQLite atau internet.

---

## 🧪 Verifikasi Dependency Rule & Quality Gates

### 1. Presentation Steril dari Database & Jaringan Langsung
```bash
git grep -n -E "Dio\(|openDatabase|getDatabasesPath|FlutterSecureStorage|SharedPreferences\.getInstance|jsonDecode" -- "lib/features/*/presentation" "lib/pages"
```
*Hasil:* **0 temuan (100% Bersih).**

### 2. Domain & Core Steril dari Framework & Package Eksternal
```bash
git grep -n -E "import 'package:flutter|import 'package:dio|import 'package:sqflite|import 'package:firebase" -- "lib/features/*/domain" "lib/core"
```
*Hasil:* **0 temuan (100% Murni Dart).**

### 3. Static Analysis & Unit Tests
```bash
flutter analyze
# Output: Analyzing _07_week_7_clean_architecture... No issues found!

flutter test
# Output: 00:00 +12: All tests passed!
```

---

## 🚀 Cara Menjalankan Proyek

1. **Clone repository dan buka direktori:**
   ```bash
   cd _07_week_7_clean_architecture
   ```
2. **Unduh dependensi:**
   ```bash
   flutter pub get
   ```
3. **Jalankan unit tests:**
   ```bash
   flutter test
   ```
4. **Jalankan aplikasi di emulator atau browser:**
   ```bash
   flutter run
   ```
