# Pipeline CI/CD

Dokumen ini menjelaskan **mengapa** pipeline disusun seperti ini, bukan hanya
apa isinya. Berkas workflow-nya ada di
[`.github/workflows/flutter-ci.yml`](../../.github/workflows/flutter-ci.yml).

---

## 1. Alur dari commit ke artefak

```
commit / pull request
        |
        v
[1] checkout  ->  [2] Java 17  ->  [3] Flutter stable + cache
        |
        v
[4] flutter pub get
        |
        v
[5] dart format --set-exit-if-changed   (gate 1)
        |
        v
[6] flutter analyze --fatal-infos       (gate 2)
        |
        v
[7] flutter test --coverage             (gate 3)
        |
        v
[8] upload coverage/lcov.info           (artefak)
        |
        v
[9] flutter build apk --release
        |
        v
[10] flutter build appbundle --release
        |
        v
[11] upload APK + AAB                   (artefak, 7 hari)
```

Karena setiap step bergantung pada step sebelumnya, kegagalan pada gate 1
sampai 3 menghentikan job sebelum build dijalankan. Ini disengaja: tidak ada
gunanya menghabiskan sekitar empat menit untuk membangun APK dari kode yang
belum lolos analisis.

---

## 2. Keputusan desain

### 2.1 Tiga gate, bukan satu

| Gate | Yang dicegah | Biaya |
| :--- | :--- | :--- |
| `dart format --set-exit-if-changed` | Perbedaan gaya yang membuat diff berisik | Kurang dari 1 detik |
| `flutter analyze --fatal-infos` | Kode yang lolos tetapi menyimpan info atau warning | Sekitar 60 detik |
| `flutter test --coverage` | Perubahan yang merusak perilaku | Sekitar 25 detik |

Urutannya dari yang paling murah. Jika format belum rapi, tidak perlu menunggu
analisis selesai untuk mengetahuinya.

`--fatal-infos` dipakai, bukan hanya `--fatal-warnings`, karena analyzer Flutter
sudah cukup senyap pada tingkat info. Membiarkan info menumpuk membuatnya
berubah menjadi kebiasaan yang diabaikan.

### 2.2 `working-directory` ke subfolder

Repository ini berisi 13 folder praktikum, dan hanya folder Week 13 yang
merupakan proyek aktif. Menjalankan `flutter test` di root akan gagal karena
root bukan proyek Flutter.

```yaml
defaults:
  run:
    working-directory: _13_week_13_ci_cd_automation
```

Konsekuensinya, path artefak pada `upload-artifact` harus ditulis dari root
repository, bukan dari working directory:

```yaml
path: |
  _13_week_13_ci_cd_automation/build/app/outputs/flutter-apk/app-release.apk
```

Ini kesalahan yang mudah terjadi: `upload-artifact` selalu membaca path relatif
terhadap root repository, tidak terpengaruh `defaults.run.working-directory`.

### 2.3 Java 17

`actions/setup-java@v4` dengan Temurin 17. Runner `ubuntu-latest` sudah punya
Java, tetapi versinya dapat berubah sewaktu-waktu. Menetapkan versi membuat
build tidak tiba-tiba gagal karena runner diperbarui.

Versi 17 dipilih karena `android/app/build.gradle.kts` menetapkan
`sourceCompatibility = JavaVersion.VERSION_17`.

### 2.4 Cache Flutter

```yaml
with:
  channel: stable
  cache: true
```

Tanpa cache, setiap run mengunduh Flutter SDK dari awal. Dengan cache, run
berikutnya memakai SDK yang sama dari cache, dan hanya `pub get` yang berjalan.
Ini memotong waktu penyiapan secara signifikan.

### 2.5 Concurrency

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Bila dua commit di-push berurutan pada branch yang sama, run pertama dibatalkan
dan hanya run terbaru yang diselesaikan. Tanpa ini, hasil run lama dapat selesai
belakangan dan menyesatkan saat ditinjau.

Grup dibentuk dari nama workflow dan ref, sehingga push ke branch berbeda tidak
saling membatalkan.

### 2.6 Izin minimum

```yaml
permissions:
  contents: read
```

Rincian alasannya ada di [`security-review.md`](security-review.md) bagian 7.

### 2.7 Dua artefak, bukan satu

| Artefak | Isi | Untuk siapa |
| :--- | :--- | :--- |
| `android-builds` | `app-release.apk` dan `app-release.aab` | Ditinjau dan diunduh untuk uji internal |
| `coverage-report` | `coverage/lcov.info` | Dibuka di alat cakupan, atau dibandingkan antar run |

`lcov.info` dipisah karena ukurannya kecil dan sering dibutuhkan tanpa perlu
mengunduh APK 50 MB.

`if-no-files-found: error` dipakai pada keduanya. Tanpa itu, langkah unggah
akan dianggap sukses meski berkas tidak ada, sehingga job hijau padahal artefak
kosong. Itu jenis kegagalan yang paling sulit disadari.

---

## 3. Yang tidak dijalankan di CI, dan alasannya

| Pemeriksaan | Mengapa tidak di CI |
| :--- | :--- |
| Integration test | Butuh emulator atau perangkat. Runner GitHub hanya menyediakan VM Linux tanpa akselerasi GPU, sehingga emulator Android tidak praktis dijalankan |
| Golden test tampilan | Belum ada, dan hasil render berbeda antar platform |
| Panggilan Gemini API | Butuh API key dan jaringan, hasilnya tidak deterministik |
| Signing rilis | Material signing tidak boleh ada di workflow pull request |
| Uji instalasi APK | Butuh perangkat nyata |

Integration test tetap tersimpan di `integration_test/app_test.dart` dan dapat
dijalankan manual pada emulator. Ini batasan yang dicatat, bukan sesuatu yang
diabaikan.

---

## 4. Versioning

`pubspec.yaml` memakai format `versi+build`:

```yaml
version: 1.1.0+2
```

| Bagian | Nilai | Alasan |
| :--- | :--- | :--- |
| `1.1.0` | versi aplikasi | Week 13 menambah kemampuan baru (pipeline CI), sehingga minor naik dari `1.0.0` |
| `2` | build number | Naik dari `1` karena ini unggahan baru |

Aturan yang dipegang:

| Perubahan | Yang naik | Contoh |
| :--- | :--- | :--- |
| Tidak kompatibel, mengubah format data | major | `1.4.2` menjadi `2.0.0` |
| Fitur baru yang kompatibel | minor | `1.4.2` menjadi `1.5.0` |
| Perbaikan bug | patch | `1.4.2` menjadi `1.4.3` |
| Setiap unggahan baru | build number | `+7` menjadi `+8` |

Build number wajib naik pada setiap unggahan, walaupun versi aplikasi tidak
berubah, karena Google Play menolak build number yang sudah dipakai.

### Tag

Tag `v1.1.0` dibuat sebagai tag anotasi pada commit yang sudah lolos pipeline.
Dengan begitu, source, log run, dan artefak dapat dihubungkan:

```
tag v1.1.0  ->  commit  ->  run GitHub Actions  ->  artefak
```

---

## 5. Cara memeriksa hasil

### 5.1 Dari GitHub

1. Buka tab **Actions** pada repository.
2. Pilih run yang ingin ditinjau.
3. Periksa setiap step. Step yang gagal ditandai silang merah.
4. Gulir ke bawah, unduh artefak pada bagian **Artifacts**.

### 5.2 Dari terminal, tanpa membuka browser

```bash
cd _13_week_13_ci_cd_automation
node tool/ci/fetch_run.mjs
```

Perintah ini mengambil detail run terakhir pada branch `main` lewat REST API
GitHub, lalu menyimpannya sebagai JSON. Ringkasan step dan artefak dicetak ke
terminal.

### 5.3 Menjalankan gate yang sama secara lokal

```bash
cd _13_week_13_ci_cd_automation
node tool/ci/local_ci.mjs
```

Skrip ini menjalankan tiga gate dengan perintah yang identik dengan workflow,
lalu menyimpan keluarannya di `tool/ci/results/`. Tujuannya agar kegagalan dapat
ditemukan sebelum push, bukan setelah menunggu antrean runner.

---

## 6. Cara membaca kegagalan

| Gejala | Penyebab yang paling sering | Tindakan |
| :--- | :--- | :--- |
| Gagal di `Verify formatting` | Berkas belum diformat | `dart format .`, tinjau diff, commit |
| Gagal di `Analyze` | Ada warning, error, atau info baru | Perbaiki kodenya, jangan turunkan `--fatal-infos` |
| Gagal di `Run tests` | Perilaku berubah atau test baru gagal | Jalankan test yang sama secara lokal |
| Gagal di `Build release APK` | Konfigurasi Gradle, versi Java, atau dependency | Baca log Gradle pada step tersebut |
| Gagal di `Upload Android builds` | Path artefak salah atau build tidak menghasilkan berkas | Periksa `if-no-files-found` dan path dari root repo |

Prinsip yang dipegang: **jangan menghapus atau melonggarkan pemeriksaan agar
workflow terlihat hijau.** Workflow yang hijau karena pemeriksaannya dimatikan
tidak memberi jaminan apa pun.
