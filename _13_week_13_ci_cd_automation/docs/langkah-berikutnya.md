# Pekerjaan Lanjutan

Pipeline sudah berjalan dan lulus. Dokumen ini mencatat apa yang **belum**
selesai, agar batas antara "sudah terbukti" dan "masih diasumsikan" tetap
terlihat.

---

## 1. Status saat ini

| Aspek | Status |
| :--- | :--- |
| Workflow CI | Berjalan pada push ke `main`, pull request, dan run manual |
| Run terakhir | #2, seluruh 15 step success, 366 detik |
| Artefak | `android-builds` 75,07 MB, `coverage-report` 3,22 KB |
| Tag | `v1.1.0` pada commit `3f12365` |
| Gate lokal | Format, analisis, dan test lulus |

Data mentahnya ada di `tool/ci/results/`. Untuk mengambil ulang:

```bash
cd _13_week_13_ci_cd_automation
node tool/ci/fetch_run.mjs
```

---

## 2. Pekerjaan manual di luar repository

Empat hal ini tidak dapat dikerjakan dari sini, dan tidak bergantung pada
pipeline. Rinciannya ada di [`security-review.md`](security-review.md).

| # | Pekerjaan | Alasan tidak otomatis |
| --- | :--- | :--- |
| 1 | Revoke API key lama di Google Cloud Console | Butuh akses akun pemilik proyek. Mengganti teks di source tidak menghapus nilai dari riwayat Git |
| 2 | Buat key baru dengan pembatasan API dan package name | Sama seperti di atas |
| 3 | Ganti signing release dengan keystore produksi | Material rahasia tidak boleh masuk repository maupun workflow pull request |
| 4 | Uji APK release di perangkat nyata | Butuh perangkat fisik. CI hanya membuktikan kompilasi berhasil |

Nomor 1 adalah yang paling mendesak. Selama key lama belum dicabut, key itu
harus dianggap masih aktif dan dapat dipakai siapa saja yang membaca riwayat
repository.

---

## 3. Celah yang perlu ditutup berikutnya

### 3.1 Pemeriksaan konfigurasi manifest

Temuan `INTERNET` di Week 13 ditemukan oleh tinjauan manual, bukan oleh CI.
Padahal justru temuan itu yang paling berbahaya: build hijau, aplikasi tidak
dapat mengakses jaringan.

Yang bisa ditambahkan: satu step yang memeriksa hasil build dengan `aapt2` atau
`apkanalyzer`, lalu gagal bila izin wajib tidak ada.

```bash
# Contoh pemeriksaan setelah build
aapt2 dump permissions build/app/outputs/flutter-apk/app-release.apk \
  | grep -q 'android.permission.INTERNET' || exit 1
```

### 3.2 Integration test di CI

Saat ini integration test hanya berjalan manual di emulator lokal. Menjalankannya
di CI membutuhkan emulator Android pada runner Linux, yang lambat dan sering
tidak stabil tanpa akselerasi perangkat keras.

Alternatif yang lebih realistis: menjalankan integration test pada perangkat
fisik yang terhubung ke mesin sendiri, di luar pipeline, lalu melampirkan
hasilnya seperti pada Week 12.

### 3.3 Ringkasan gate untuk pembaca tanpa akun

Step ringkasan menulis ke `GITHUB_STEP_SUMMARY`, dan blok itu hanya dirender
bagi pengguna yang sudah masuk. Pengunjung anonim tetap hanya melihat status
dan artefak.

Bila bukti harus terbaca publik, jalannya adalah menyimpan keluaran gate
sebagai berkas di repository, seperti yang sudah dilakukan pada
`tool/ci/results/` dan `screenshots/`.

---

## 4. Cara memperbarui versi Flutter di CI

Versi SDK dipatok di dua tempat, dan keduanya harus berubah bersamaan:

| Tempat | Nilai sekarang |
| :--- | :--- |
| `pubspec.yaml` bagian `environment.sdk` | `^3.13.5` |
| `.github/workflows/flutter-ci.yml` bagian `flutter-version` | `3.47.6` |

Bila SDK di mesin pengembang dinaikkan, ubah `flutter-version` di workflow pada
commit yang sama. Tanpa itu, pipeline akan terus menguji versi lama dan
perbedaan baru tidak terdeteksi.

Setelah mengubahnya, jalankan gate lokal lebih dulu:

```bash
node tool/ci/local_ci.mjs
```

Bila lokal lulus dan CI gagal, penyebabnya ada di lingkungan runner, bukan di
kode. Itulah gunanya mematok versi.
