# Laporan Praktikum Week 6: Authentication, Security & FCM

**Nama:** MOKHAMAD RIZKI HADIONO SINGGIH  
**NIM:** 244107020198  
**Kelas:** TI-3G - Pemrograman Mobile  

---

## 1. Praktikum 1: Login + Secure Storage + Token Refresh
Pada praktikum pertama ini, dilakukan implementasi sistem autentikasi pengguna serta penyimpanan token JWT yang aman di tingkat perangkat.

* **Penyimpanan Token Aman:** `TokenStore` dibuat memanfaatkan `flutter_secure_storage` untuk menyimpan `access_token` dan `refresh_token`. Metode ini wajib digunakan sebagai pengganti `SharedPreferences` karena data disandikan dengan enkripsi hardware (Android KeyStore dan iOS Keychain).
* **Dio Interceptor & Auto-Refresh:** Membuat `api_client.dart` dengan InterceptorsWrapper. Setiap request HTTP otomatis menyisipkan header `Authorization: Bearer <token>`. Jika server mengembalikan status **401 Unauthorized**, Interceptor otomatis meminta token baru dengan `refresh_token`, menyimpan token baru, dan mengulang (*retry*) request yang gagal secara transparan. Jika refresh token kedaluwarsa, sesi dibersihkan dan pengguna dipaksa login ulang.
* **Provider & Guard Route:** Menggunakan Riverpod `AsyncNotifierProvider` (`authStateProvider`) yang terintegrasi dengan `GoRouter` untuk melindungi rute aplikasi (*protected routes*). Pengguna yang belum login otomatis dialihkan ke halaman `/login`.

---

## 2. Praktikum 2: FCM, Permission, dan Token Lifecycle
Pada praktikum kedua, dilakukan integrasi layanan push notification berbasis Firebase Cloud Messaging (FCM) pada aplikasi Flutter.

* **Inisialisasi & Runtime Permission:** Proyek dihubungkan ke Firebase Console dengan menambahkan file `google-services.json` dan memanggil `Firebase.initializeApp()` saat startup. Izin notifikasi runtime dipinta menggunakan `requestNotificationPermission()`.
* **Pengelolaan Token FCM:** Mengambil token perangkat dengan `getToken()` saat aplikasi dibuka dan mendengarkan perubahan token secara *real-time* via `onTokenRefresh` untuk mencegah *stale token* di server backend.
* **Topic Messaging:** Mendaftarkan perangkat ke topik broadcast kampus `pengumuman-kampus` menggunakan `subscribeToTopic()` untuk penerimaan pengumuman massal.

---

## 3. Praktikum 3: Payload, Tiga App State, Klik, dan Topik
Pada tahap ini, diimplementasikan penanganan notifikasi pesan gabungan (*notification + data payload*) pada 3 kondisi lifecycle aplikasi.

* **Top-Level Background Handler:** Menambahkan fungsi `@pragma('vm:entry-point') firebaseMessagingBackgroundHandler` sebagai entry point mandiri agar notifikasi background dapat diproses pada Isolate terpisah.
* **Penanganan 3 App State:**
  1. **Foreground:** Banner notifikasi sistem tidak muncul otomatis saat aplikasi terbuka, sehingga dipemicu secara manual menggunakan `flutter_local_notifications` melalui `onMessage`.
  2. **Background:** Banner notifikasi sistem muncul di tray, dan klik di-handle melalui `onMessageOpenedApp` untuk mengarahkan pengguna ke rute pengumuman.
  3. **Terminated:** Aplikasi mati total yang dibuka melalui notifikasi ditangani oleh `getInitialMessage()` di `main()`, langsung mengarahkan layar ke detail pengumuman.

![Praktikum 6](Screenshots/1.png)  
![Praktikum 6](Screenshots/2.png)
![Praktikum 6](Screenshots/3.png)
![Praktikum 6](Screenshots/4.png)
![Praktikum 6](Screenshots/5.png)
![Praktikum 6](Screenshots/6.png)

---

## 4. AI Challenge: Evaluasi Security & FCM Architecture

Selama mengerjakan tugas ini, dilakukan evaluasi rekomendasi keamanan storage dan arsitektur FCM menggunakan AI. Berikut ringkasannya:

### A. Diskusi Evaluasi Storage Engine & Security
* **Prompt yang digunakan:** "Aplikasi Flutter Campus Notification App: Login + JWT + FCM. Bandingkan SharedPreferences dan FlutterSecureStorage untuk menyimpan access_token & refresh_token. Jelaskan risiko keamanan dan buatkan PushService serta Dio Interceptor refresh token."
* **Hasil & Evaluasi:** 
  1. AI dengan tepat melarang penggunaan SharedPreferences untuk menyimpan JWT token karena disimpan dalam format XML plain text tanpa enkripsi yang rawan dibaca pada perangkat *rooted*.
  2. AI merekomendasikan **FlutterSecureStorage** untuk kredensial sensitif dan **Dio Interceptor** untuk otomatisasi penanganan error 401. Rekomendasi ini diterima sepenuhnya.
  3. Namun, kode draf awal AI **disesuaikan**. AI sempat mencetak token FCM penuh pada log console dan menyisakan listener `onTokenRefresh` tanpa callback backend. Bagian tersebut diperbaiki secara mandiri dengan memotong token log dan memasangkan callback `onToken`.

### B. Output AI Assistant (Perbandingan Storage & Keamanan Flutter)

| Kriteria | SharedPreferences | FlutterSecureStorage |
| --- | --- | --- |
| **Metode Enkripsi** | Tidak Ada (Plain Text / Unencrypted XML) | Terenkripsi (Android KeyStore / AES, iOS Keychain) |
| **Keamanan Root/Jailbreak** | Sangat Rentan (Dapat dibaca via ADB / file inspector) | Sangat Aman (Master Key disimpan di Hardware Security Module) |
| **Tujuan Penggunaan** | Preferensi UI (Tema, bahasa, toggle setting) | Kredensial Sensitif (JWT Tokens, API Keys, Password Hash) |
| **Performa Akses** | Sangat Cepat (In-Memory Data Store) | Asynchronous I/O (Overhead dekripsi ringan) |

**Rekomendasi Final & Alasan**

| Kebutuhan | Rekomendasi Storage | Alasan Utama |
| --- | --- | --- |
| **Preferensi UI / Tema** | **SharedPreferences** | Data primitif non-sensitif (boolean/string) yang membutuhkan akses cepat tanpa overhead enkripsi. |
| **JWT Access & Refresh Token** | **FlutterSecureStorage** | Mencegah kejahatan *Account Takeover* dengan menyandikan token menggunakan enkripsi hardware tingkat OS. |

**Trade-off Setiap Pilihan:**
* **SharedPreferences:** Cepat dan mudah diimplementasikan, tetapi sama sekali tidak aman untuk menyimpan kredensial autentikasi.
* **FlutterSecureStorage:** Sangat aman dengan enkripsi hardware OS, tetapi beroperasi secara asynchronous dan membutuhkan penanganan exception native.

### C. AI Verification Checklist & Keputusan Final

* **Apakah background handler berupa fungsi top-level dengan `@pragma('vm:entry-point')`?**
  Ya. AI memberikan fungsi top-level di luar class agar dapat dipanggil oleh OS di isolate terpisah saat aplikasi di latar belakang.
* **Apakah `onTokenRefresh` benar-benar mengirim token baru ke backend?**
  Tidak pada draf awal AI. AI hanya mencetak komentar log. Kode diperbaiki dengan menghubungkan fungsi callback `onToken` ke endpoint API backend.
* **Apakah foreground memakai local notification manual?**
  Ya. AI memanfaatkan `flutter_local_notifications` untuk menampilkan banner lokal secara manual ketika pesan FCM masuk di state foreground.
* **Apakah klik dari ketiga state (foreground/background/terminated) masuk ke rute yang benar?**
  Ya. Didukung oleh fungsi helper `routeFromMessage()` yang mengekstraksi data rute payload (misal `/pengumuman/3`).

**Keputusan Final Penulis:**  
Berdasarkan evaluasi di atas, diputuskan untuk menggunakan `FlutterSecureStorage` untuk pengelolaan token dan `Dio Interceptor` untuk siklus refresh token. Penggunaan fungsi top-level untuk FCM background handler dan local notification untuk foreground banner diterapkan sepenuhnya sesuai standar industri.

---

## 5. Refactoring Challenge & Testing
Setelah fitur autentikasi dan push notification berjalan, struktur kode dirapikan dan diuji:

* **Modularisasi & Refactoring:** Memisahkan konstanta rute ke `lib/routes.dart`, memisahkan parser rute ke fungsi murni `routeFromMessage()`, serta memindahkan pemetaan `DioException` ke `lib/data/api_errors.dart`.
* **Cek Kebersihan Kode:** Menjalankan `flutter analyze`. Hasil akhir: No issues found!
* **Automated Testing:** Membuat pengujian unit di `test/auth_push_test.dart` menggunakan `FakeTokenStore`. Pengujian membuktikan parsing rute FCM tahan data null/tanpa slash, payload membawa ID pengumuman, dan sesi dibersihkan saat refresh token gagal.

![Praktikum 6](Screenshots/9.png)
![Praktikum 6](Screenshots/7.png)
![Praktikum 6](Screenshots/8.png)
---

## 6. Tugas Utama: Industry Challenge (Campus Notify App)
Tugas akhir ini adalah penyempurnaan dari seluruh modul, menggabungkan Dio, FlutterSecureStorage, GoRouter, dan FCM menjadi aplikasi pengumuman kampus `campus_notify`.

* **Protected Routing:** Pengguna yang belum login dicegat oleh `GoRouter` dan dialihkan ke `/login`.
* **Deep-Linking Notifikasi:** Klik notifikasi dari state foreground, background, maupun terminated secara otomatis membuka halaman detail pengumuman (`/pengumuman/:id`).
* **Matriks Pengujian 3 State Aplikasi:**
  - *Foreground:* Banner lokal muncul, klik masuk ke `/pengumuman/3`.
  - *Background:* Banner sistem muncul di tray, klik masuk ke `/pengumuman/3`.
  - *Terminated:* Cold-start aplikasi via `getInitialMessage()`, langsung masuk ke `/pengumuman/3`.

**Screenshot Hasil:**
* Tampilan Halaman Login (Guard Route Active):
  ![Praktikum 6](Screenshots/11.png)
* Tampilan Halaman Utama Pengumuman:
  ![Praktikum 6](Screenshots/12.png)
* Tampilan Detail Pengumuman via Deep-Link Notifikasi:
  ![Praktikum 6](Screenshots/13.png)
* Tampilan Banner Notifikasi Foreground & Background:
  ![Praktikum 6](Screenshots/14.png)
  ![Praktikum 6](Screenshots/15.png)
* Hasil Running Unit Test & Flutter Analyze (All Tests Passed):
  ![Praktikum 6](Screenshots/10.png)

---

## 7. Refleksi

1. **Mengapa refresh token tidak boleh disimpan di SharedPreferences? Apa risikonya bila bocor?**
   `SharedPreferences` menyimpan data dalam format XML plain text tanpa enkripsi di penyimpanan lokal. Pada perangkat yang ter-root atau melalui backup ADB, file tersebut mudah dicuri. Jika `refresh_token` bocor, penyerang dapat meminta `access_token` baru atas nama korban secara terus-menerus (*Account Takeover*) bahkan setelah kata sandi diubah. Oleh sebab itu, wajib menggunakan `FlutterSecureStorage` yang terenkripsi hardware KeyStore/Keychain.

2. **Apa yang rusak bila `onTokenRefresh` diabaikan selama satu semester perkuliahan?**
   FCM Token perangkat dapat berubah akibat reinstall aplikasi, clear data, atau rotasi keamanan Firebase. Jika `onTokenRefresh` diabaikan, backend akan menyimpan token basi (*stale token*). Akibatnya selama satu semester, mahasiswa tidak akan pernah menerima notifikasi pengumuman kampus karena backend mengirim ke token yang sudah invalid.

3. **Kapan memakai topik dan kapan memakai token perangkat? Beri contoh pesan kampus untuk masing-masing.**
   Topik (`subscribeToTopic`) digunakan untuk siaran massal (*broadcast*), misalnya *"Pengumuman Libur Nasional"* atau *"Jadwal KRS Semester Ganjil"*. Sebaliknya, token perangkat digunakan untuk pesan privat/personal yang sensitif, misalnya *"Peringatan Tunggakan UKT NIM 244107020198"* atau *"Notifikasi Nilai Ujian Akhir"*.

4. **Bagian mana dari rekomendasi AI yang ditolak, dan mengapa?**
   Logging token FCM secara penuh ke console log yang diusulkan draf awal AI ditolak karena berisiko memicu kebocoran kredensial di lingkungan produksi (*security vulnerability*). Log tersebut dimodifikasi agar hanya menampilkan 15 karakter awal token. Selain itu, callback `onTokenRefresh` yang kosong dari AI disesuaikan dengan menambahkan fungsi pengiriman token teranyar ke backend.
