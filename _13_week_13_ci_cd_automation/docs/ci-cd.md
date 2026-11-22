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

### 2.7 Versi Flutter dipatok, bukan mengikuti `stable`

```yaml
with:
  flutter-version: '3.47.6'
  channel: stable
  cache: true
```

Rancangan awal memakai `channel: stable` saja. Run pertama membuktikan itu
bermasalah: langkah **Analyze** gagal di runner padahal perintah yang sama
lulus di mesin pengembang.

Yang dapat dipastikan dari luar hanya dua hal:

| Fakta | Sumber |
| :--- | :--- |
| Run #1 gagal pada step 9 (`Analyze`), exit code 1 | Daftar step lewat REST API |
| Run #2 lulus seluruhnya setelah versi dipatok ke `3.47.6` | Daftar step lewat REST API |

Log step tidak dapat dibaca tanpa masuk ke GitHub, sehingga teks diagnostik
yang dikeluarkan analyzer tidak dapat dikutip di sini. Dugaan yang paling masuk
akal adalah pergeseran versi SDK: `stable` di runner mengikuti rilis terbaru,
sementara mesin pengembang memakai `3.47.6`. Analyzer versi lebih baru dapat
memunculkan diagnostik tingkat info yang belum ada di versi lama, dan gate ini
memakai `--fatal-infos`.

Dugaan itu tidak dapat dibuktikan dari sini, dan laporan ini tidak
menuliskannya sebagai fakta. Yang diputuskan tetap sama, karena alasannya
berlaku terlepas dari penyebab pastinya:

| Pendekatan | Kelebihan | Kekurangan |
| :--- | :--- | :--- |
| `channel: stable` saja | Selalu menguji versi terbaru | Hasil dapat berubah tanpa ada perubahan kode. Kegagalan sulit direproduksi di mesin sendiri |
| `flutter-version` dipatok | CI dan lokal memakai SDK yang sama, kegagalan selalu dapat direproduksi | Pembaruan SDK harus dilakukan sengaja lewat commit |

Yang dipilih adalah versi dipatok. Menaikkan versi Flutter kemudian menjadi
perubahan yang terlihat di diff, bukan kejutan pada suatu pagi. Bila gate
kembali gagal setelah versi dinaikkan, penyebabnya pasti ada di kode, bukan di
lingkungan.

Konsekuensi yang perlu dijaga: angka versi di workflow harus ikut diperbarui
ketika SDK di mesin pengembang naik. Bila tidak, pipeline akan terus menguji
versi lama dan perbedaan baru tidak terdeteksi.

### 2.8 Ringkasan gate ditulis ke halaman run

Log mentah sebuah job hanya dapat dibuka oleh pengguna yang sudah masuk ke
GitHub. Pada repository publik sekalipun, halaman run menampilkan
`Sign in to view logs` bagi pengunjung tanpa akun. Ini terlihat langsung pada
run yang sudah selesai: status dan artefak terbaca, log tidak.

Karena itu setiap gate menulis keluarannya ke berkas lewat `tee`, dan satu step
tambahan merangkumnya:

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

`if: always()` dipakai agar ringkasan tetap dibuat ketika salah satu gate gagal,
yaitu justru saat ringkasan paling dibutuhkan.

`set -o pipefail` dipakai pada ketiga gate. Tanpa itu, `perintah | tee berkas`
mengembalikan kode keluar `tee`, yang hampir selalu nol, sehingga gate yang
gagal tetap dianggap lulus.

### 2.9 Batas yang perlu diketahui

Ringkasan di atas tampil pada halaman run bagi pengguna yang sudah masuk.
Pengunjung tanpa akun tetap hanya melihat status dan artefak, karena GitHub
tidak menampilkan blok ringkasan step kepada pengunjung anonim.

Pemeriksaan pada halaman run tanpa masuk menunjukkan hal itu: blok ringkasan
tidak dirender sama sekali. Artinya tujuan "penyebab kegagalan terbaca tanpa
masuk" **tidak tercapai** oleh pendekatan ini.

Yang tetap tercapai adalah penghematan langkah bagi pemilik repository: saat
run merah, penyebabnya sudah terlihat di halaman run tanpa perlu membuka log
step satu per satu. Untuk pembaca luar, bukti disediakan dengan cara lain:
keluaran gate dilampirkan sebagai berkas di `tool/ci/results/` dan dirender
menjadi gambar di `screenshots/`.

### 2.10 Dua artefak, bukan satu

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

Untuk mengubah keluaran itu menjadi gambar, jalankan:

```bash
node tool/ci/render.mjs
```

Hasilnya empat PNG di `screenshots/`, dibuat dari berkas hasil yang sebenarnya,
bukan teks yang ditulis ulang di dalam skrip.

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
