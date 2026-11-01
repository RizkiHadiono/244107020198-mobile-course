# Week 10 — AI Feature Integration (Asisten Pintar POLINEMA)

**Mata Kuliah:** Pemrograman Mobile
**Nama:** Mokhamad Rizki Hadiono Singgih
**NIM:** 244107020198
**Kelas:** TI-3G
**Prodi:** D-IV Teknik Informatika — Politeknik Negeri Malang

---

## Ringkasan

Modul ini menambahkan **satu fitur AI** ke aplikasi catatan hasil refactor Week 7:
**Asisten Pintar POLINEMA** — chat assistant berbasis **Google Gemini API**
(`gemini-1.5-flash`) yang dibungkus mengikuti **feature-first Clean Architecture**
(`domain` murni Dart, `data` menangani HTTP & secure storage, `presentation` menangani UI).

Fitur wajib codelab yang dipenuhi:

| Ketentuan codelab | Implementasi |
| :--- | :--- |
| Integrasi satu fitur AI | Chat assistant (Gemini LLM) |
| `flutter_secure_storage` untuk API key | `AiService` + `ApiKeySettingsPage` |
| Prompt design (system + user + batas) | `AiService.systemInstruction` + `docs/ai-log.md` |
| Chat interface + loading indicator | `ChatScreen` (bubble, auto-scroll, indikator "sedang berpikir") |
| Fallback saat AI error | Bubble `isError` + dialog *Layanan AI Mengalami Kendala* |
| Tabel risiko + mitigasi | Bagian [Risiko & Mitigasi](#-risiko--mitigasi) |
| Green machine evidence | Bagian [Bukti Mesin Hijau](#-bukti-mesin-hijau) |
| `lib/`, `docs/`, `README.md`, `screenshots/` | Semua tersedia |

---

## Struktur Modul AI

```
lib/features/ai_chat/
├── data/
│   ├── datasources/ai_service.dart        # HTTP ke Gemini + secure storage + error mapping
│   └── repositories/ai_repository_impl.dart  # sanitasi riwayat (10 pesan terakhir)
├── domain/
│   ├── entities/chat_message.dart         # entity immutable (sender, timestamp, isError)
│   ├── repositories/ai_repository.dart    # kontrak antarmuka
│   └── usecases/send_message.dart         # validasi input + delegasi ke repo
└── presentation/
    ├── pages/chat_screen.dart             # UI chat + privacy guard + fallback dialog
    ├── pages/api_key_settings.dart        # CRUD API key (masked preview)
    └── providers/chat_providers.dart      # Riverpod Notifier & state
```

Rute GoRouter: `/chat` dan `/chat/settings`. Titik masuk: ikon robot pada AppBar `NotesPage`.

---

## Cara Menjalankan

```bash
flutter pub get
flutter analyze            # harus: No issues found!
flutter test               # harus: All tests passed!
flutter run                # pilih device
```

Lalu di aplikasi: login → ikon **robot** di AppBar → ikon **kunci** → tempel Gemini API Key
dari <https://aistudio.google.com/app/apikey> → kembali ke chat dan mulai bertanya.

Regenerasi screenshot dokumentasi:

```bash
flutter test tool/capture_screenshots.dart
```

---

## 🔒 Risiko & Mitigasi

| Risiko | Dampak | Mitigasi yang diterapkan |
| :--- | :--- | :--- |
| **Bocor API key** | Kunci disalahgunakan pihak lain | Key tidak pernah ditulis di kode; disimpan lewat `flutter_secure_storage` (Android Keystore / iOS Keychain). Dapat dihapus kapan pun dari halaman pengaturan. |
| **Bocor data pribadi (PII)** | NIK / rekening terkirim ke cloud | **Client-side guard**: regex `\b\d{16}\b` memblokir pesan sebelum request dibuat. Ditambah larangan eksplisit pada `systemInstruction`. |
| **Biaya / token membengkak** | Kuota API cepat habis | Riwayat dibatasi **10 pesan terakhir**, `maxOutputTokens: 500`, `temperature: 0.7`. |
| **API error / down / rate limit** | Aplikasi terasa "hang" atau crash | Setiap status (400/403/429/500, timeout) dipetakan ke pesan ramah; UI menampilkan bubble error + dialog fallback berisi saran dan tombol *Cek API Key*. |
| **Respons tidak relevan / terlalu panjang** | Layout rusak, sulit dibaca | Persona + batas panjang pada system instruction ("maksimal 3-4 kalimat"), jawaban wajib Bahasa Indonesia. |

---

## 🧪 Bukti Mesin Hijau

```text
$ flutter analyze
Analyzing _10_week_10_ai_feature_integration...
No issues found!

$ flutter test
00:02 +28: All tests passed!
```

28 test lulus — termasuk 7 test baru untuk fitur AI:

| Test | Yang dibuktikan |
| :--- | :--- |
| `AiService` tanpa API key | Melempar `AiServiceException` dengan pesan yang dapat ditampilkan |
| `AiService` HTTP 200 | Parsing `candidates[0].content.parts[0].text` benar |
| `AiService` HTTP 400/403 | Dipetakan ke pesan "API Key tidak valid" |
| `AiService` HTTP 429 | Dipetakan ke pesan rate limit |
| `SendMessageUseCase` input kosong | `ArgumentError` sebelum menyentuh jaringan |
| Repo saat exception | Mengembalikan `ChatMessage` dengan `isError = true` (UI tidak crash) |
| Repo saat sukses | Mengembalikan `ChatMessage` dari sender `ai` |

---

## 📸 Screenshots

| # | File | Keterangan |
| :--- | :--- | :--- |
| 1 | `screenshots/screenshot-01-notes-page-ai-button.png` | Titik masuk fitur AI pada halaman catatan |
| 2 | `screenshots/screenshot-02-chat-screen-conversation.png` | Percakapan + bubble error/fallback |
| 3 | `screenshots/screenshot-03-api-key-settings.png` | Pengelolaan API key di secure storage |
| 4 | `screenshots/screenshot-04-privacy-guard-nik.png` | NIK 16 digit diblokir sebelum dikirim |
| 5 | `screenshots/screenshot-05-fallback-dialog.png` | Dialog fallback saat layanan AI gagal |

---

## Dokumentasi Pendukung

- [`docs/ai-log.md`](docs/ai-log.md) — system prompt, user prompt, output awal AI, uji adversarial privasi.
- [`Laporan-Praktikum-Week-10.md`](Laporan-Praktikum-Week-10.md) — laporan praktikum lengkap.
