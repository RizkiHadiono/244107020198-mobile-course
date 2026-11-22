# Laporan Praktikum Week 13: CI/CD & Otomatisasi

**Nama:** MOKHAMAD RIZKI HADIONO SINGGIH
**NIM:** 244107020198
**Kelas:** TI-3G, Pemrograman Mobile
**Program Studi:** D-IV Teknik Informatika
**Jurusan:** Teknologi Informasi, Politeknik Negeri Malang
**Tanggal:** 23 November 2026

---

## 1. Tujuan Praktikum

1. Menjelaskan alur CI/CD dari commit hingga artefak aplikasi.
2. Membuat workflow untuk format, analisis, test, dan build Android.
3. Menyimpan APK dan AAB sebagai artefak yang dapat ditinjau.
4. Menerapkan versioning dan memahami batasan penyimpanan secret.

---

## 2. Objek Praktikum

Proyek yang dipakai adalah aplikasi catatan dari Week 12, disalin ke folder
`_13_week_13_ci_cd_automation` dengan nama package
`week13_ci_cd_automation`.

| Aspek | Sebelum (Week 12) | Sesudah (Week 13) |
| :--- | :--- | :--- |
| Nama package | `week12_testing_quality_assurance` | `week13_ci_cd_automation` |
| Versi | `1.0.0+1` | `1.1.0+2` |
| Jumlah test | 97 | 97 |
| Workflow CI | tidak ada | `.github/workflows/flutter-ci.yml` |
| Izin INTERNET | hanya di manifest debug | juga di manifest utama |
| Format kode | 23 berkas belum rapi | seluruhnya rapi |

Proyek ini dipilih karena sudah memiliki test yang berjalan, sehingga pipeline
langsung punya sesuatu yang layak diperiksa. Pipeline tanpa test hanya akan
memeriksa format dan kompilasi.

---

## 3. Landasan Teori

### 3.1 CI dan CD

**Continuous integration** menjalankan pemeriksaan otomatis setiap kali
perubahan diajukan atau di-push. **Continuous delivery** mengotomatiskan
penyiapan rilis sampai artefak siap diambil. **Continuous deployment** melangkah
lebih jauh dengan mengirim rilis ke pengguna tanpa campur tangan manusia.

Praktikum ini berhenti di continuous delivery: artefak dihasilkan dan disimpan,
tetapi tidak diunggah ke Play Store.

### 3.2 Mengapa otomatisasi diperlukan

| Masalah pemeriksaan manual | Cara CI mengatasinya |
| :--- | :--- |
| Mudah terlewat saat tergesa-gesa | Selalu dijalankan, tanpa kecuali |
| Sulit direproduksi di mesin lain | Lingkungan ditetapkan di berkas workflow |
| Hasilnya tidak tercatat | Setiap run punya log dan artefak permanen |
| Bergantung pada siapa yang memeriksa | Aturannya sama untuk semua orang |

### 3.3 Gate kualitas

Gate adalah pemeriksaan yang menghentikan proses bila gagal. Pipeline ini
memakai tiga gate berurutan: format, analisis, dan test. Build hanya berjalan
setelah ketiganya lulus.

Urutan dari yang paling murah ke paling mahal penting, karena kegagalan murah
sebaiknya diketahui lebih dulu.

---

## 4. Persiapan Proyek

### 4.1 Penyalinan dan penamaan ulang

Folder Week 12 disalin ke `_13_week_13_ci_cd_automation`, tanpa menyertakan
`build/`, `.dart_tool/`, `coverage/`, `.gradle/`, dan `ephemeral/`. Nama package
diubah di seluruh berkas:

| Berkas | Yang diubah |
| :--- | :--- |
| `pubspec.yaml` | `name`, `description`, `version` |
| Seluruh `lib/`, `test/`, `integration_test/` | `import` |
| `android/app/build.gradle.kts` | `namespace`, `applicationId` |
| `android/app/src/main/kotlin/...` | path paket dan `package` di `MainActivity.kt` |

### 4.2 Versi

```yaml
version: 1.1.0+2
```

Minor naik dari `1.0.0` karena Week 13 menambah kemampuan baru berupa pipeline
otomatis. Build number naik dari `1` ke `2` karena ini unggahan baru.

### 4.3 Format kode

Pemeriksaan pertama yang dijalankan adalah `dart format --set-exit-if-changed .`
dan hasilnya **gagal**: 23 dari 68 berkas belum mengikuti format Dart. Ini wajar
karena Week 1 sampai Week 12 belum pernah menjalankan formatter.

Perbaikannya satu kali jalan:

```bash
dart format .
```

Perubahan format dipisahkan ke commit tersendiri agar diff logika dan diff gaya
tidak bercampur saat ditinjau.

### 4.4 Izin INTERNET

Ditemukan bahwa `android.permission.INTERNET` hanya ada di
`android/app/src/debug/AndroidManifest.xml`. Manifest debug tidak ikut ke build
release, sehingga APK release dapat dibangun tetapi seluruh permintaan jaringan
akan gagal.

Izin ditambahkan ke manifest utama:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

### 4.5 Label aplikasi

`android:label` diubah dari `Asisten Pintar POLINEMA` menjadi `Clean Notes`
agar sesuai dengan nama aplikasi yang dipakai di dalam kode.

### 4.6 Material signing

`.gitignore` ditambah agar material signing tidak pernah masuk repository:

```gitignore
/android/key.properties
*.jks
*.keystore
*.p12
```

Konfigurasi signing sendiri **tidak** diubah. Alasan dan rencananya ada di
[`docs/security-review.md`](docs/security-review.md).

---

## 5. Workflow CI

### 5.1 Isi workflow

Berkas `.github/workflows/flutter-ci.yml` berisi satu job dengan 15 step:

| # | Step | Jenis |
| ---: | :--- | :--- |
| 1 | Checkout repository | persiapan |
| 2 | Set up Java 17 (Temurin) | persiapan |
| 3 | Set up Flutter 3.47.6 + cache | persiapan |
| 4 | Tampilkan versi Flutter dan Dart | informasi |
| 5 | `flutter pub get` | persiapan |
| 6 | Install `libsqlite3-dev` | persiapan |
| 7 | `dart format --set-exit-if-changed .` | **gate 1** |
| 8 | `flutter analyze --fatal-infos` | **gate 2** |
| 9 | `flutter test --coverage` | **gate 3** |
| 10 | Ringkas hasil gate ke halaman run | informasi |
| 11 | Upload `coverage/lcov.info` | artefak |
| 12 | `flutter build apk --release` | build |
| 13 | `flutter build appbundle --release` | build |
| 14 | Upload APK dan AAB | artefak |
| 15 | Post action dan penutupan job | persiapan |

Step 15 bukan step yang ditulis sendiri, melainkan penutupan otomatis dari
`actions/checkout`, `actions/setup-java`, dan `actions/subosito-flutter-action`.
Pada halaman run, step penutup ini tampil dengan nomor 28 sampai 31, bukan 16
sampai 19. Nomor yang meloncat itu berasal dari penomoran internal GitHub, dan
tidak memengaruhi hasil.

### 5.2 Pemicu

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:
```

`pull_request` memeriksa perubahan sebelum digabung. `push` memastikan branch
utama selalu dalam keadaan sehat. `workflow_dispatch` memungkinkan run manual
tanpa commit baru, berguna saat meninjau ulang konfigurasi.

### 5.3 Izin dan concurrency

```yaml
permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Izin dibatasi pada membaca kode. Concurrency membatalkan run lama pada ref yang
sama sehingga hanya hasil terbaru yang ditinjau.

### 5.4 Working directory

```yaml
defaults:
  run:
    working-directory: _13_week_13_ci_cd_automation
```

Repository berisi 13 folder praktikum, sehingga perintah Flutter harus
dijalankan di dalam folder proyek.

Konsekuensi yang perlu diingat: `actions/upload-artifact` **tidak** terpengaruh
`working-directory`. Path artefaknya harus ditulis dari root repository:

```yaml
path: |
  _13_week_13_ci_cd_automation/build/app/outputs/flutter-apk/app-release.apk
  _13_week_13_ci_cd_automation/build/app/outputs/bundle/release/app-release.aab
```

### 5.5 Mengapa `libsqlite3-dev` dipasang

Test repository memakai `sqflite_common_ffi` untuk menjalankan SQLite sungguhan
di Dart VM. Di Linux, paket `sqlite3` memuat `libsqlite3` secara dinamis. Tanpa
pustaka itu, unit test SQL akan gagal di runner meski lulus di mesin pengembang
Windows.

Ini contoh perbedaan lingkungan yang harus ditangani eksplisit di pipeline.

### 5.6 Versi Flutter dipatok

```yaml
with:
  flutter-version: '3.47.6'
  channel: stable
  cache: true
```

Rancangan awal hanya memakai `channel: stable`. Run pertama gagal di step
`Analyze`, dan setelah versi dipatok, run kedua lulus. Rincian kegagalan itu
ada di bagian 7.4 dan 7.5.

### 5.7 Ringkasan gate di halaman run

Setiap gate menulis keluarannya ke berkas lewat `tee`, lalu satu step
tambahan merangkum 40 baris terakhir ke `GITHUB_STEP_SUMMARY`:

```yaml
- name: Ringkas hasil gate ke halaman run
  if: always()
  run: |
    {
      echo "## Ringkasan gate"
      for f in format.log analyze.log test.log; do
        echo "### \`$f\`"
        tail -n 40 "$f"
      done
    } >> "$GITHUB_STEP_SUMMARY"
```

`if: always()` dipakai agar ringkasan tetap dibuat saat ada gate yang gagal,
yaitu justru saat paling dibutuhkan. `set -o pipefail` dipasang pada ketiga
gate supaya `perintah | tee berkas` tidak menyembunyikan kode keluar perintah
yang sebenarnya.

---

## 6. Verifikasi Lokal

Sebelum push, ketiga gate dijalankan pada mesin lokal dengan perintah yang
identik dengan workflow.

| Gate | Perintah | Hasil |
| :--- | :--- | :--- |
| Format | `dart format --output=none --set-exit-if-changed .` | 68 berkas, 0 berubah |
| Analisis | `flutter analyze --fatal-infos` | `No issues found!` |
| Test | `flutter test --coverage` | 97 test lulus |

Untuk memudahkan pengulangan, gate yang sama dibungkus dalam satu skrip:

```bash
node tool/ci/local_ci.mjs
```

Skrip ini menyimpan keluaran setiap gate ke `tool/ci/results/`, sehingga bukti
lokal dan bukti dari GitHub Actions dapat dibandingkan berdampingan.

---

## 7. Hasil

### 7.1 Verifikasi lokal

Ketiga gate dijalankan lewat satu skrip agar perintahnya persis sama dengan
workflow:

```bash
node tool/ci/local_ci.mjs
```

| Gate | Perintah | Exit code | Durasi |
| :--- | :--- | ---: | ---: |
| Format | `dart format --output=none --set-exit-if-changed .` | 0 | 1,7 detik |
| Analisis | `flutter analyze --fatal-infos` | 0 | 61,1 detik |
| Test | `flutter test --coverage` | 0 | 28,8 detik |

Keluaran mentahnya tersimpan di `tool/ci/results/` dan ditampilkan di bawah ini.

| <img src="screenshots/ci-local-format.png" width="760" alt="Keluaran gate format"> | <img src="screenshots/ci-local-analyze.png" width="760" alt="Keluaran gate analyze"> |
| :---: | :---: |
| **Gate 1** lulus, 68 berkas, 0 berubah | **Gate 2** lulus, `No issues found!` |

<img src="screenshots/ci-local-test.png" width="760" alt="Keluaran gate test">

<img src="screenshots/ci-local-coverage.png" width="760" alt="Ringkasan cakupan baris">

Cakupan dihitung dari `coverage/lcov.info`:

| Ukuran | Nilai |
| :--- | ---: |
| Berkas di `lib/` yang terukur | 32 |
| Baris ditemukan | 1143 |
| Baris dieksekusi | 848 |
| Cakupan baris | 74,19 % |

Angka ini hanya mencakup test unit dan widget. Integration test tidak masuk
hitungan karena membutuhkan emulator dan tidak dijalankan di CI.

### 7.2 Build release

Build dijalankan setelah ketiga gate lulus, dengan perintah yang sama seperti
di workflow.

| Artefak | Perintah | Ukuran | Durasi |
| :--- | :--- | ---: | ---: |
| `app-release.apk` | `flutter build apk --release` | 54.917.245 byte (52,37 MB) | 244,8 detik |
| `app-release.aab` | `flutter build appbundle --release` | 53.649.881 byte (51,16 MB) | 20,3 detik |

APK jauh lebih besar daripada AAB karena APK yang dihasilkan bersifat
universal: seluruh ABI (`arm64-v8a`, `armeabi-v7a`, `x86_64`) dan seluruh
kepadatan layar dimasukkan ke satu berkas. AAB diserahkan ke Play Store dalam
bentuk terpecah per perangkat, sehingga ukuran unduhan sebenarnya lebih kecil
daripada angka AAB itu sendiri.

Build kedua jauh lebih cepat karena cache Gradle dari build pertama masih
hangat. Di runner GitHub Actions, build pertama selalu dingin sehingga waktu
keduanya hampir sama.

### 7.3 Verifikasi di GitHub Actions

Workflow dijalankan pada repository setelah push. Dua run tercatat, dan run
pertama **gagal**. Kegagalan itu bagian dari hasil, bukan sesuatu yang dihapus
dari laporan.

| Run | Commit | Event | Status | Durasi | Step gagal |
| ---: | :--- | :--- | :--- | ---: | :--- |
| #1 | `7b54649` | push | failure | 70 detik | step 9 `Analyze` |
| #2 | `3f12365` | push | **success** | 366 detik | tidak ada |

Run #1: <https://github.com/RizkiHadiono/244107020198-mobile-course/actions/runs/45056115379>

Run #2: <https://github.com/RizkiHadiono/244107020198-mobile-course/actions/runs/45056450753>

<img src="screenshots/ci-run-list.png" width="760" alt="Daftar run pada tab Actions">

Gambar di atas memperlihatkan dua run berurutan: run #1 bertanda silang merah,
run #2 bertanda centang hijau.

### 7.4 Kegagalan run pertama

Run #1 berhenti di step `Analyze` dengan exit code 1, sementara perintah yang
sama lulus di mesin lokal beberapa jam sebelumnya. Tiga gate lain tidak
berjalan karena job dihentikan, dan seluruh langkah build ikut terlewati.

Yang dapat dipastikan dari luar hanya dua hal:

| Fakta | Sumber |
| :--- | :--- |
| Step 9 `Analyze` berstatus failure, step 10 dan seterusnya `skipped` | `tool/ci/results/` dan REST API |
| Run #2 lulus seluruhnya setelah versi Flutter dipatok ke `3.47.6` | REST API |

Log step tidak dapat dibaca tanpa masuk ke GitHub, sehingga teks diagnostik
analyzer tidak dapat dikutip. Dugaan yang paling masuk akal adalah pergeseran
versi SDK, karena workflow saat itu memakai `channel: stable` yang mengikuti
rilis terbaru, sementara mesin lokal memakai `3.47.6`. Analyzer versi lebih baru
dapat memunculkan diagnostik tingkat info yang belum ada sebelumnya, dan gate
ini memakai `--fatal-infos`.

Dugaan tersebut **tidak terbukti** dari data yang tersedia, dan laporan ini
tidak menuliskannya sebagai fakta.

<img src="screenshots/ci-run-failed.png" width="760" alt="Run pertama gagal pada step Analyze">

Gambar di atas memperlihatkan run #1 berhenti di `Analyze`, sementara step
`Run tests with coverage` sampai `Upload Android builds` berstatus terlewati.
Pola inilah yang membuat urutan gate menjadi penting: kesalahan pada pemeriksaan
termurah menghentikan seluruh pekerjaan berikutnya, termasuk build empat menit
yang tidak perlu dijalankan.

### 7.5 Perbaikan

| Perubahan | Alasan |
| :--- | :--- |
| `flutter-version: '3.47.6'` menggantikan `channel: stable` saja | CI dan lokal memakai SDK yang sama, sehingga kegagalan dapat direproduksi |
| `actions/checkout@v5` dan `actions/setup-java@v5` | Versi v4 memicu peringatan deprecasi Node 20 |
| Setiap gate menulis keluaran lewat `tee`, ditambah step ringkasan | Penyebab kegagalan terlihat di halaman run tanpa membuka log step satu per satu |

Perbaikan versi SDK dipilih walaupun penyebab pastinya belum diketahui, karena
alasannya berlaku terlepas dari itu: pipeline yang menguji versi yang bergerak
sendiri akan gagal pada waktu yang tidak dapat diperkirakan, dan kegagalannya
tidak dapat direproduksi di mesin pengembang.

### 7.6 Hasil run kedua

Run #2 selesai dalam 366 detik dengan seluruh step berstatus success.

<img src="screenshots/ci-run-summary.png" width="760" alt="Ringkasan run kedua, status Success dan dua artefak">

<img src="screenshots/ci-run-steps.png" width="760" alt="Seluruh step run kedua berstatus success">

Rincian waktu per step:

| # | Step | Durasi |
| ---: | :--- | ---: |
| 1 | Set up job | 1 detik |
| 2 | Checkout repository | 3 detik |
| 3 | Set up Java | 0 detik |
| 4 | Set up Flutter | 26 detik |
| 5 | Tampilkan versi Flutter dan Dart | 1 detik |
| 6 | Install dependencies | 8 detik |
| 7 | Install SQLite library | 3 detik |
| 8 | Verify formatting | 0 detik |
| 9 | Analyze | 11 detik |
| 10 | Run tests with coverage | 30 detik |
| 11 | Ringkas hasil gate ke halaman run | 0 detik |
| 12 | Upload coverage report | 1 detik |
| 13 | Build release APK | **235 detik** |
| 14 | Build release App Bundle | 12 detik |
| 15 | Upload Android builds | 3 detik |
| 28 | Post Set up Flutter | 25 detik |
| 29 | Post Set up Java | 0 detik |
| 30 | Post Checkout repository | 0 detik |
| 31 | Complete job | 0 detik |
| | **Total** | **366 detik** |

Satu angka menonjol: build APK memakan 235 detik, sekitar 64 persen dari total
waktu run. Ketiga gate yang menjadi inti pemeriksaan hanya memakan 41 detik
(step 8 sampai 10). Ini memperkuat keputusan menaruh build di urutan terakhir:
kesalahan format atau test berhenti jauh sebelum empat menit terbuang.

`Analyze` hanya 11 detik di runner, jauh lebih cepat daripada 61 detik di mesin
lokal, karena runner tidak memiliki proses lain yang berebut CPU dan cache
analyzer sudah terbentuk setelah `pub get`.

### 7.7 Artefak

| Artefak | Ukuran | Isi | Masa simpan |
| :--- | ---: | :--- | ---: |
| `android-builds` | 78.712.630 byte (75,07 MB) | `app-release.apk` dan `app-release.aab` | 7 hari |
| `coverage-report` | 3.301 byte (3,22 KB) | `coverage/lcov.info` | 7 hari |

Keduanya berstatus `expired=false` saat data diambil, dan keduanya terbentuk
dari build sungguhan di runner, bukan dari mesin lokal.

Ukuran `android-builds` lebih besar daripada jumlah APK dan AAB lokal
(52,37 MB + 51,16 MB = 103,53 MB) karena artefak disimpan dalam bentuk zip
terkompresi, sehingga dua berkas yang banyak berbagi isi dapat dipadatkan
menjadi 75,07 MB.

Data mentah run tersimpan di `tool/ci/results/run-45056450753.json` dan
`tool/ci/results/artifacts-45056450753.json`.

---

## 8. Versioning dan Tag

### 8.1 Versi

```yaml
version: 1.1.0+2
```

### 8.2 Tag

Tag `v1.1.0` dibuat sebagai tag anotasi pada commit yang sudah lolos pipeline,
bukan pada commit sebelumnya. Urutannya penting: tag menandai keadaan kode yang
terbukti hijau di CI, sehingga artefak yang diunduh dari run tersebut dapat
dicocokkan dengan tag.

```bash
git tag -a v1.1.0 -m "Week 13: CI/CD dan otomatisasi rilis"
git push origin v1.1.0
```

Hasil verifikasi:

```
$ git tag -n --list "v1.1.0"
v1.1.0          Week 13: CI/CD dan otomatisasi rilis

$ git log -1 --format='%H %d'
3f12365f821839b46850e42a2b4b3495331f0a78  (HEAD -> main, tag: v1.1.0, origin/main)
```

| Aspek | Nilai |
| :--- | :--- |
| Nama tag | `v1.1.0` |
| Jenis | anotasi, bukan lightweight |
| Commit | `3f12365` |
| Run yang membuktikan | #2, seluruh 15 step success |
| Pesan tag | memuat tautan ke halaman run dan nama artefak |

Tag anotasi dipilih karena menyimpan pesan, tanggal, dan pembuat tag di dalam
objek Git tersendiri. Lightweight tag hanya menunjuk ke commit tanpa metadata,
sehingga tautan ke run CI tidak dapat disimpan di dalamnya.

Cara memeriksa bahwa tag menunjuk ke commit yang benar:

```bash
git show v1.1.0 --stat --oneline | head -5
git rev-parse v1.1.0^{commit}
```

---

## 9. Risiko Keamanan

Rincian lengkap ada di [`docs/security-review.md`](docs/security-review.md).
Ringkasannya:

| # | Temuan | Tingkat | Status |
| :--- | :--- | :--- | :--- |
| 1 | API key Gemini tertulis di source, repository publik | Tinggi | Nilai diganti placeholder, **key lama perlu di-revoke** |
| 2 | Release ditandatangani debug keystore | Sedang | Didokumentasikan, belum diubah |
| 3 | `INTERNET` hanya di manifest debug | Sedang | Diperbaiki |
| 4 | `--dart-define` dapat diekstrak dari APK | Rendah | Tidak ada nilai sensitif di sana |
| 5 | `google-services.json` memuat API key Firebase | Rendah | Dibiarkan, memang publik by design |

Temuan nomor 1 adalah yang paling penting. Mengganti teks di source tidak
menghapus nilai dari riwayat Git, sehingga key tersebut harus dianggap bocor dan
di-revoke di Google Cloud Console.

---

## 10. Kendala

| # | Kendala | Solusi |
| :--- | :--- | :--- |
| 1 | Format gagal pada 23 berkas | `dart format .` sekali jalan, commit terpisah |
| 2 | `upload-artifact` tidak mengikuti `working-directory` | Path artefak ditulis dari root repository |
| 3 | Test SQL butuh `libsqlite3` di Linux | Step `apt-get install libsqlite3-dev` |
| 4 | Integration test butuh emulator | Tidak dijalankan di CI, dicatat sebagai batasan |
| 5 | APK release tanpa izin INTERNET | Izin ditambahkan ke manifest utama |
| 6 | API key ditemukan di source publik | Diganti placeholder, revoke dicatat sebagai langkah manual |
| 7 | Run #1 gagal di `Analyze` padahal lulus lokal | Versi Flutter dipatok ke `3.47.6`, tidak lagi mengikuti `stable` |
| 8 | Log step tidak dapat dibaca tanpa akun GitHub | Setiap gate menulis keluaran lewat `tee`, ditambah step ringkasan di halaman run |
| 9 | Peringatan deprecasi Node 20 pada `actions/checkout@v4` | Dinaikkan ke v5 |

---

## 11. Refleksi

### Yang berubah dari cara kerja sebelumnya

Sebelum Week 13, semua pemeriksaan bergantung pada ingatan. Saya menjalankan
`flutter analyze` dan `flutter test` karena memang sedang mengerjakan kode, bukan
karena ada yang memaksa. Begitu pekerjaan selesai dan perhatian berpindah,
pemeriksaan itu berhenti.

Pipeline membalik hubungan itu. Pemeriksaan berjalan karena ada commit, bukan
karena ada orang yang ingat. Perbedaannya terlihat langsung pada gate pertama:
`dart format --set-exit-if-changed .` gagal pada 23 dari 68 berkas, dan itu
berkas dari Week 1 sampai Week 12 yang selama ini dianggap sudah rapi. Tidak
ada yang salah dengan kode itu. Yang tidak pernah ada adalah pemeriksa yang
konsisten.

### Temuan yang paling mengubah cara saya membaca hasil build

Izin `INTERNET` yang hanya ada di manifest debug adalah pelajaran paling
berguna di minggu ini. Build release tetap **berhasil**, APK tetap terbentuk,
dan tidak ada satu pun peringatan di log. Aplikasi hanya akan gagal saat
dijalankan, ketika setiap permintaan jaringan ditolak.

Artinya "build hijau" hanya membuktikan kode dapat dikompilasi. Ia tidak
membuktikan aplikasi berfungsi. Pipeline yang baik karena itu perlu memeriksa
konfigurasi, bukan hanya hasil kompilasi. Pada proyek ini pemeriksaan tersebut
belum otomatis, dan itu tercatat sebagai batasan, bukan sesuatu yang dianggap
selesai.

### Bagian yang membuat saya mengubah rancangan

Rancangan pertama saya menaruh build sebelum test, dengan alasan agar artefak
cepat tersedia. Setelah dihitung, build APK memakan sekitar empat menit
sementara tiga gate hanya sekitar satu setengah menit. Menaruh build di depan
berarti setiap kesalahan format membuang empat menit waktu runner. Urutan
akhirnya dibalik: gate termurah lebih dulu, build terakhir.

Hal serupa terjadi pada `upload-artifact`. Path-nya harus ditulis dari root
repository walaupun perintah Flutter berjalan di subfolder. Tanpa
`if-no-files-found: error`, kesalahan path itu akan menghasilkan job hijau
dengan artefak kosong, jenis kegagalan yang paling sulit disadari karena tidak
ada yang berwarna merah.

### Batas antara otomatis dan manual

Tidak semua temuan dapat diselesaikan pipeline. API key yang sudah ter-push
tidak dapat dihapus dari riwayat Git oleh workflow mana pun, dan keystore
produksi justru tidak boleh berada di workflow yang berjalan untuk pull
request. Keduanya berakhir sebagai langkah manual yang tercatat di
[`docs/security-review.md`](docs/security-review.md).

Ini pelajaran kedua: otomatisasi memindahkan pekerjaan, bukan menghilangkannya.
Yang berubah adalah pekerjaan yang tersisa menjadi lebih jelas dan lebih
sedikit, karena bagian yang dapat diperiksa mesin sudah diambil alih.

### Kegagalan yang justru paling mengajarkan

Run pertama gagal. Perintah `flutter analyze --fatal-infos` yang lulus di mesin
lokal memerahkan job di runner, dan sampai sekarang penyebab pastinya tidak
dapat saya baca karena log step hanya terbuka bagi pengguna yang masuk.

Yang bisa saya lakukan hanya dua: memastikan perintahnya identik, lalu mengunci
variabel yang paling mungkin berbeda. Variabel itu adalah versi SDK, karena
workflow memakai `channel: stable` sementara mesin lokal memakai `3.47.6`.
Setelah versi dipatok, run kedua lulus.

Saya tidak menuliskan "penyebabnya versi SDK" sebagai kesimpulan, karena itu
dugaan yang tidak terbukti dari data yang saya miliki. Yang dapat dikatakan:
memakai `stable` membuat pipeline menguji versi yang bergerak sendiri, dan
kegagalan seperti itu tidak dapat direproduksi di mesin sendiri. Alasan itu
sudah cukup untuk memilih versi yang dipatok, tanpa perlu tahu penyebab
pastinya.

### Yang belum tercapai pada laporan ini

Tiga hal masih terbuka dan sengaja tidak ditutupi:

| # | Yang belum tercapai | Alasan |
| --- | :--- | :--- |
| 1 | Penyebab pasti kegagalan run #1 | Log step butuh akun GitHub. Yang ada hanya status step dan dugaan yang tidak terbukti |
| 2 | Ringkasan gate terbaca oleh pengunjung tanpa akun | GitHub tidak merender blok ringkasan step untuk pengunjung anonim. Manfaatnya hanya terasa bagi pemilik repository |
| 3 | Pemeriksaan konfigurasi manifest di CI | Temuan `INTERNET` masih bergantung pada tinjauan manual, belum ada step yang memeriksanya |

Poin ketiga adalah celah yang paling perlu ditutup berikutnya. Seluruh temuan
lain di minggu ini ditemukan oleh pemeriksaan otomatis, tetapi justru temuan
paling berbahaya ditemukan oleh mata.

---

## 12. Kesimpulan

1. Pipeline CI untuk proyek ini terdiri dari tiga gate berurutan (format,
   analisis, test) dan baru membangun APK serta AAB setelah ketiganya lulus.
   Seluruh gate lulus di mesin lokal: 68 berkas rapi, `No issues found!`, dan
   97 test lulus dengan cakupan 74,19 % baris.

2. Menyiapkan pipeline menemukan empat masalah yang tidak terlihat dari
   pekerjaan manual: 23 berkas belum diformat, izin `INTERNET` tidak ada di
   manifest utama, label aplikasi tidak sesuai, dan satu API key tertulis di
   source publik. Temuan ketiga adalah yang paling berbahaya karena build tetap
   hijau sementara aplikasi release tidak dapat mengakses jaringan.

3. Workflow memakai izin minimum (`contents: read`), tidak memakai secret, dan
   membatalkan run lama pada ref yang sama lewat `concurrency`. Artefak APK dan
   AAB diunggah dengan `if-no-files-found: error` dan disimpan tujuh hari,
   sehingga job tidak dapat berstatus hijau dengan artefak kosong. Pada run
   kedua, artefak `android-builds` berukuran 75,07 MB dan `coverage-report`
   3,22 KB.

4. Versi naik dari `1.0.0+1` menjadi `1.1.0+2`, mengikuti aturan bahwa fitur
   baru menaikkan minor dan setiap unggahan menaikkan build number. Tag anotasi
   `v1.1.0` dibuat pada commit `3f12365`, yaitu commit yang lulus pipeline pada
   run #2.

5. Pipeline tidak langsung hijau. Run pertama gagal di `Analyze` karena
   workflow mengikuti `channel: stable` sementara mesin lokal memakai Flutter
   `3.47.6`. Versi SDK dipatok, dan run kedua lulus seluruh 15 step dalam 366
   detik. Kegagalan itu bukan gangguan, melainkan hasil pertama yang jujur:
   pipeline menguji lingkungan yang berbeda dari mesin pengembang.

6. Batas yang masih terbuka: integration test tidak berjalan di CI karena
   membutuhkan emulator, signing rilis masih memakai debug keystore, API key
   lama perlu di-revoke manual, dan belum ada pemeriksaan konfigurasi manifest
   di CI. Keempatnya tercatat sebagai pekerjaan lanjutan, bukan sebagai hal yang
   sudah selesai.

---

## 13. Lampiran

### 13.1 Perintah yang digunakan

```bash
# Persiapan
flutter pub get
dart format .

# Gate yang sama dengan CI
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test --coverage

# Bukti lokal
node tool/ci/local_ci.mjs
node tool/ci/render.mjs

# Bukti dari GitHub Actions
node tool/ci/fetch_run.mjs

# Build manual
flutter build apk --release
flutter build appbundle --release
```

### 13.2 Berkas keluaran

| Berkas | Isi |
| :--- | :--- |
| `tool/ci/results/01-format.txt` | Keluaran gate format |
| `tool/ci/results/02-analyze.txt` | Keluaran gate analisis |
| `tool/ci/results/03-test.txt` | Keluaran gate test |
| `tool/ci/results/04-coverage.txt` | Ringkasan cakupan |
| `tool/ci/results/local-ci.json` | Ringkasan seluruh gate |
| `tool/ci/results/run-45056450753.json` | Detail run GitHub Actions yang lulus |
| `tool/ci/results/artifacts-45056450753.json` | Daftar artefak run |

### 13.3 Tautan run

| Run | Tautan |
| ---: | :--- |
| #1 (failure) | <https://github.com/RizkiHadiono/244107020198-mobile-course/actions/runs/45056115379> |
| #2 (success) | <https://github.com/RizkiHadiono/244107020198-mobile-course/actions/runs/45056450753> |
