# Tinjauan Keamanan Pipeline

Dokumen ini mencatat risiko keamanan yang ditemukan saat menyiapkan CI/CD, apa
yang sudah ditangani, dan apa yang sengaja dibiarkan sebagai langkah manual.

Codelab Week 13 menekankan tiga hal: permission minimum, secret tidak masuk
repository, dan kesadaran bahwa build sukses belum berarti siap publikasi.
Bagian ini adalah penerapannya pada proyek ini.

---

## 1. Ringkasan temuan

| # | Temuan | Tingkat | Status |
| :--- | :--- | :--- | :--- |
| 1 | API key Gemini tertulis langsung di source dan sudah ter-push ke repository publik | Tinggi | Nilai di source sudah diganti placeholder. **Key lama perlu di-revoke manual.** |
| 2 | Release build ditandatangani dengan debug keystore | Sedang | Didokumentasikan. Belum diubah, karena keystore produksi tidak boleh ada di workflow PR. |
| 3 | `INTERNET` hanya ada di manifest debug | Sedang | Diperbaiki: izin ditambahkan ke manifest utama. |
| 4 | `--dart-define` mudah diekstrak dari APK | Rendah | Didokumentasikan. Tidak ada nilai sensitif yang dikirim lewat `--dart-define`. |
| 5 | `google-services.json` berisi API key Firebase | Rendah | Dibiarkan. Key ini memang publik dan dibatasi package name serta SHA-1. |
| 6 | Workflow tidak memakai secret apa pun | Tidak ada | Justru kondisi yang aman untuk pull request. |

---

## 2. Temuan 1: API key di dalam source

### Apa yang terjadi

Berkas `tool/capture_screenshots.dart` pada folder Week 10 dan Week 11 memuat
nilai API key yang ditulis langsung sebagai nilai balik sebuah fake repository:

```dart
Future<String?> getApiKey() async => 'AIza...';
```

Nilai itu dipakai agar skrip pengambilan screenshot dapat berjalan tanpa
membuka halaman pengaturan. Niatnya praktis, tetapi konsekuensinya serius:
repository ini **publik**, sehingga key tersebut dapat dibaca siapa saja.

### Mengapa berbahaya

API key Google AI Studio yang tidak dibatasi dapat dipakai pihak lain untuk
memanggil Gemini atas biaya pemilik kunci. Tidak ada tanda di aplikasi bahwa
kuota sedang dipakai orang lain, sehingga penyalahgunaan baru terlihat di
tagihan atau saat kuota habis.

### Yang sudah dilakukan

Nilai di kedua berkas diganti dengan placeholder:

```dart
Future<String?> getApiKey() async => 'CONTOH_KEY_GANTI_SENDIRI';
```

### Yang masih harus dilakukan manual

Mengganti teks di source **tidak menghapus nilai dari riwayat Git**. Commit
lama masih memuat key tersebut, dan siapa pun dapat membacanya lewat riwayat.
Langkah yang benar:

1. Buka Google Cloud Console, cari API key tersebut, lalu **revoke**.
2. Buat key baru bila masih diperlukan.
3. Batasi key baru pada API yang dipakai saja, dan bila memungkinkan pada
   package name serta SHA-1 aplikasi.
4. Simpan key baru di GitHub Actions Secrets bila nanti dipakai pipeline.

Langkah 1 tidak dapat diotomatiskan dari sini karena memerlukan akses ke akun
Google Cloud pemilik proyek.

### Pelajaran

Nilai yang hanya dipakai untuk kenyamanan pengembangan cepat tetap harus
diperlakukan sebagai secret bila bentuknya kredensial. Untuk kasus ini, skrip
seharusnya membaca key dari environment variable, bukan menuliskannya di kode.

---

## 3. Temuan 2: debug keystore pada release build

`android/app/build.gradle.kts` masih memakai konfigurasi bawaan Flutter:

```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

### Dampak

| Aspek | Kondisi sekarang |
| :--- | :--- |
| APK dapat diinstal | Ya |
| Dapat diunggah ke Google Play | Tidak |
| Dapat diperbarui di atas instalasi sebelumnya | Tidak, karena sidik jari sertifikat berbeda |
| Cocok untuk uji internal | Ya |

### Mengapa tidak langsung diperbaiki

Codelab secara eksplisit meminta material signing tidak disuntikkan pada
workflow yang berjalan untuk pull request. Menambahkan signing sekarang berarti
menyiapkan empat secret (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`,
`KEY_ALIAS`, `KEY_PASSWORD`) dan workflow rilis terpisah. Itu pekerjaan yang
lebih besar daripada cakupan Week 13, dan berisiko bila dikerjakan setengah
jalan.

Yang dilakukan sekarang: memastikan material signing tidak akan pernah masuk
repository bila nanti ditambahkan.

```gitignore
/android/key.properties
*.jks
*.keystore
*.p12
```

### Rencana bila rilis sungguhan dibutuhkan

1. Buat keystore, simpan di tempat aman di luar repository.
2. Simpan nilainya sebagai GitHub Actions Secrets.
3. Buat workflow terpisah yang hanya berjalan pada tag `v*`, bukan pada
   `pull_request`.
4. Decode keystore ke berkas sementara, jalankan build, lalu hapus berkas
   tersebut di step akhir.
5. Jangan pernah mencetak isi secret ke log.

---

## 4. Temuan 3: izin INTERNET tidak ada di release

Sebelum Week 13, `android.permission.INTERNET` hanya dideklarasikan di
`android/app/src/debug/AndroidManifest.xml`. Manifest debug tidak ikut ke build
release, sehingga APK release yang dihasilkan CI dapat dibangun dengan sukses
tetapi seluruh permintaan jaringan akan gagal.

Ini contoh persis dari peringatan codelab: **build hijau bukan jaminan aplikasi
berfungsi**. CI hanya memeriksa bahwa kompilasi berhasil, bukan bahwa aplikasi
dapat menghubungi server.

Perbaikan:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Ditempatkan di `android/app/src/main/AndroidManifest.xml`.

### Batas pengujian otomatis

Tidak ada test otomatis yang menangkap masalah ini. Yang bisa dilakukan:

| Cara | Biaya | Yang ditangkap |
| :--- | :--- | :--- |
| Integration test di emulator | Tinggi, perlu perangkat | Perilaku nyata, termasuk akses jaringan |
| Pemeriksaan manifest di CI | Rendah | Izin yang wajib ada benar benar ada |
| Tinjauan manual sebelum rilis | Sedang | Konfigurasi yang tidak tercakup test |

Saat ini baru cara ketiga yang dijalankan, dan itulah sebabnya temuan ini
tercatat di laporan.

---

## 5. Temuan 4: `--dart-define` bukan tempat menyimpan secret

Codelab mengingatkan bahwa nilai yang dikirim lewat `--dart-define` ikut
dikompilasi ke dalam aplikasi dan dapat diekstrak dari APK.

Proyek ini memakai `--dart-define` hanya untuk dua hal:

| Nilai | Isi | Sensitif |
| :--- | :--- | :--- |
| `PERF_MODE` | `true` atau `false` untuk mengaktifkan instrumentasi performa | Tidak |
| `PERF_IMAGE_BASE` | Alamat dasar gambar saat profiling lokal | Tidak |

Tidak ada API key, token, atau password yang dikirim lewat jalur ini. API key
Gemini dimasukkan pengguna saat runtime dan disimpan lewat
`flutter_secure_storage`, bukan dikompilasi ke aplikasi.

---

## 6. Temuan 5: `google-services.json`

Berkas `google-services.json` pada folder Week 6 memuat API key Firebase.

Berkas ini **memang dirancang untuk publik**. Key di dalamnya hanya berfungsi
sebagai pengenal proyek Firebase, dan Google membatasinya berdasarkan package
name serta SHA-1 sertifikat aplikasi. Menyalin key tersebut ke aplikasi lain
tidak memberi akses.

Karena itu berkas ini dibiarkan apa adanya. Yang tetap perlu diperiksa manual
adalah aturan pembatasan di Firebase Console, karena pembatasan itu yang
sebenarnya melindungi proyek.

---

## 7. Izin workflow

```yaml
permissions:
  contents: read
```

Job ini hanya membaca kode dan mengunggah artefak. Tidak ada langkah yang
menulis ke repository, membuat issue, atau menerbitkan rilis, sehingga
`contents: read` sudah mencukupi.

Hal yang **tidak** diberikan, dan alasannya:

| Izin | Mengapa tidak diberikan |
| :--- | :--- |
| `contents: write` | Tidak ada langkah yang perlu menulis ke repository |
| `pull-requests: write` | Workflow tidak berkomentar pada pull request |
| `packages: write` | Tidak ada paket yang diterbitkan |
| `id-token: write` | Tidak memakai OIDC ke cloud provider |

Prinsipnya sederhana: izin yang tidak dipakai tidak diminta. Bila nanti ada
kebutuhan menulis, izin ditambahkan pada job yang benar benar memerlukannya,
bukan pada level workflow.

---

## 8. Pull request dari fork

Pull request dari fork tidak mendapat akses ke GitHub Secrets repository.
Workflow ini tidak memakai secret sama sekali, sehingga tidak ada perbedaan
perilaku antara pull request dari cabang sendiri dan dari fork.

Keadaan ini justru menguntungkan: workflow dapat dijalankan pada pull request
pihak luar tanpa risiko membocorkan kredensial.

---

## 9. Daftar periksa sebelum rilis

Daftar ini belum dijalankan seluruhnya, dan itu disengaja. Tujuannya agar
sisa pekerjaan terlihat jelas.

| # | Langkah | Status |
| :--- | :--- | :--- |
| 1 | Revoke API key lama di Google Cloud Console | Belum, perlu akses akun |
| 2 | Ganti signing release dengan keystore produksi | Belum, di luar cakupan |
| 3 | Simpan material signing di GitHub Secrets | Belum |
| 4 | Buat workflow rilis terpisah untuk tag `v*` | Belum |
| 5 | Uji APK release di perangkat nyata | Belum |
| 6 | Periksa aturan pembatasan di Firebase Console | Belum |
| 7 | Pastikan `version` di pubspec naik sebelum unggah | Ya, `1.1.0+2` |
| 8 | Tandai commit yang lolos dengan tag | Ya, `v1.1.0` |
| 9 | Izin INTERNET tersedia di release | Ya |
| 10 | Workflow memakai izin minimum | Ya, `contents: read` |
