# Modul 09: AI-Assisted Development / Vibe Coding

**Nama Mahasiswa:** MOKHAMAD RIZKI HADIONO SINGGIH
**NIM:** `244107020198`
**Kelas:** TI-3G - Pemrograman Mobile
**Program Studi:** D4 Teknik Informatika, Politeknik Negeri Malang

> Folder portfolio ini memenuhi deliverable codelab Week 9 (`09-week-9-ai-assisted-development/`): struktur `docs/`, `README.md`, dan `screenshots/`.

---

## 📌 Ringkasan

Week 9 menambahkan **satu fitur kecil** ke project Week 7 yang sudah lolos review — bukan membuat project baru. Fitur yang ditambahkan (sesuai permintaan eksplisit codelab): **pencarian judul catatan (search) + empty state**, dibangun dengan siklus AI lengkap: *prompt → generate → verify → test → refactor → explain*.

## ✨ Fitur yang Ditambahkan

1. **Search judul real-time** pada halaman daftar catatan (search bar di atas list).
2. **Case-insensitive** — query `belajar` menemukan `Belajar Clean Architecture`.
3. **Empty state ganda** — pesan berbeda untuk "belum ada catatan" vs "tidak ada catatan yang cocok".
4. **Filter di domain, bukan widget** — aturan filter hidup di use case murni `SearchNotes` (mematuhi dependency rule).

## 🛠️ Stack Teknologi

Flutter 3.47.6 · Dart 3.13.5 · Riverpod (Notifier) · GoRouter · sqflite · Clean Architecture feature-first

## 🚀 Cara Menjalankan

```bash
cd _07_week_7_clean_architecture
flutter pub get
flutter test        # 21/21 passed (15 lama + 6 baru untuk search)
flutter analyze     # No issues found
flutter run         # jalankan aplikasi
```

> Widget test search kini me-render `NotesPage` nyata dengan provider palsu (3 catatan + auth login), lalu mengetik query dan memverifikasi empty state — bukan lagi widget statis.

## ✅ Bukti Mesin Hijau

| Pemeriksaan | Hasil | Bukti |
|---|---|---|
| `flutter analyze` | No issues found | `screenshots/bukti-01-flutter-analyze.txt` |
| `flutter test` | 21/21 passed | `screenshots/bukti-02-flutter-test.txt` |
| `dart format --set-exit-if-changed .` | 0 changed (exit 0) | `screenshots/bukti-03-dart-format.txt` |
| Domain steril dari framework | 0 temuan | `screenshots/bukti-04-grep-sterilitas.txt` |

## 🤖 Hasil Siklus AI (ringkasan — detail di `docs/ai-log.md`)

- **Prompt 5 slot** + konteks nyata Week 7 ditempel (tanpa secret).
- **3 halusinasi/bug AI terbukti saat generate:** (H1) filter case-sensitive → diperbaiki `toLowerCase()`; (H2) provider fiktif `notesProvider` → diganti `notesNotifierProvider`; (H3) saran SQL `LIKE` di UI → **ditolak** (melanggar dependency rule + risiko injection).
- **Review AI kedua (terpisah):** 1 blocker-benar diperbaiki (R1: getter `visibleNotes` tidak reaktif → diganti **`visibleNotesProvider`** yang di-`ref.watch`); 1 saran-benar diperbaiki (R2: widget test diperkuat me-render `NotesPage` nyata); 1 saran ditolak beralasan (R3: normalisasi query ganda redundan).
- **Keputusan per file:** 1 terima, 5 terima+refactor, 2 tolak+tulis manual — semua beralasan teknis.
- **Refactor:** filter dipindah dari widget ke use case domain; daftar terfilter via provider turunan reaktif; `NotesPage` jadi `ConsumerStatefulWidget` agar controller di-`dispose()`.

## 📂 Struktur Folder

```text
_09_week_9_ai_assisted_development/
├── README.md                 # berkas ini
├── docs/
│   └── ai-log.md             # prompt mentah, output AI, verifikasi, tabel keputusan
└── screenshots/              # bukti output mesin (dijalankan nyata)
    ├── bukti-01-flutter-analyze.txt
    ├── bukti-02-flutter-test.txt
    ├── bukti-03-dart-format.txt
    └── bukti-04-grep-sterilitas.txt
```

## 💭 Refleksi

- **Halusinasi yang ditemukan:** yang paling halus adalah H1 — filter yang *tampak* benar tapi case-sensitive, hanya terbukti lewat satu test kecil yang gagal. Ini menegaskan prinsip "klaim AI adalah hipotesis sampai ada bukti".
- **Prompt paling membantu:** formula 5 slot (terutama slot *Batas*: "jangan panggil SQLite dari widget") mencegah AI menghasilkan kode lintas layer.
- **Refactor pada kode AI:** memindahkan filter dari widget ke `SearchNotes` use case murni — membuatnya testable tanpa rendering.
- **Keputusan tersulit:** menolak saran "optimasi" SQL `LIKE` (H3) — terlihat efisien, tetapi melanggar arsitektur dan membuka celah injection; dipilih filter in-memory yang aman dan sesuai dependency rule.
