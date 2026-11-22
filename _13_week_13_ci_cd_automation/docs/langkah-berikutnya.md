# Langkah Berikutnya

Seluruh berkas untuk Week 13 sudah siap di working tree. Dokumen ini mencatat
apa yang masih harus dijalankan, dalam urutan yang benar, beserta berkas mana
yang perlu diisi setelahnya.

Repository ini memakai hook global `~/.githooks/pre-commit` yang menolak commit
dari agent. Karena itu commit, push, dan tag dilakukan manual oleh pemilik
repository memakai `gcommit` dan `gpush` yang sudah tersedia di profil
PowerShell.

---

## 1. Tinjau perubahan

```bash
cd C:\Semester_5\Pemograman_Mobile\244107020198-mobile-course
git status
git diff -- README.md
```

Yang belum ter-track:

| Path | Isi |
| :--- | :--- |
| `.github/workflows/flutter-ci.yml` | Workflow CI |
| `_13_week_13_ci_cd_automation/` | Proyek Week 13 lengkap dengan dokumen dan bukti |

Yang berubah:

| Path | Perubahan |
| :--- | :--- |
| `README.md` | Baris Week 13 pada tabel modul |
| `_10_.../tool/capture_screenshots.dart` | API key diganti placeholder |
| `_11_.../tool/capture_screenshots.dart` | API key diganti placeholder |

---

## 2. Commit

Dua commit, dipisah agar perbaikan keamanan tidak bercampur dengan penambahan
proyek baru.

```bash
git add _10_week_10_ai_feature_integration/tool/capture_screenshots.dart `
        _11_week_11_performance_optimization/tool/capture_screenshots.dart
gcommit -m "Keamanan | Ganti API key contoh pada tool screenshot"

git add .github _13_week_13_ci_cd_automation README.md
gcommit -m "Week 13 | CI/CD & Otomatisasi"
```

---

## 3. Push dan tunggu run pertama

```bash
gpush
```

Lalu buka tab **Actions** pada repository dan pilih workflow **Flutter CI**.
Run pertama akan berjalan pada branch `main`.

Perkiraan waktu: 6 sampai 8 menit, dengan sekitar 4 menit dihabiskan untuk
`flutter build apk --release`.

Bila ada step yang gagal, urutan pemeriksaannya ada di
[`ci-cd.md`](ci-cd.md) bagian 6.

---

## 4. Ambil data run sebagai bukti

```bash
cd _13_week_13_ci_cd_automation
node tool/ci/fetch_run.mjs
```

Skrip ini membaca run terakhir pada `main` lewat REST API GitHub, lalu
menyimpan:

| Berkas | Isi |
| :--- | :--- |
| `tool/ci/results/run-<id>.json` | Detail run, job, dan status tiap step |
| `tool/ci/results/artifacts-<id>.json` | Nama, ukuran, dan status artefak |

Untuk run tertentu, tambahkan id-nya sebagai argumen:

```bash
node tool/ci/fetch_run.mjs 1234567890
```

---

## 5. Tangkap layar halaman run

Halaman yang perlu diambil:

| Halaman | Yang ditunjukkan |
| :--- | :--- |
| `https://github.com/RizkiHadiono/244107020198-mobile-course/actions` | Daftar run, run terbaru berstatus success |
| Halaman run tersebut | Seluruh 13 step hijau beserta durasinya |
| Bagian **Artifacts** di bawah halaman run | `android-builds` dan `coverage-report` |

Simpan sebagai:

| Berkas | Isi |
| :--- | :--- |
| `screenshots/ci-run-list.png` | Daftar run di tab Actions |
| `screenshots/ci-run-steps.png` | Step 1 sampai 13 berstatus success |
| `screenshots/ci-run-artifacts.png` | Dua artefak beserta ukurannya |

---

## 6. Isi bagian laporan yang menunggu

Cari penanda berikut, lalu ganti dengan isi yang sebenarnya.

| Penanda | Berkas | Diisi dengan |
| :--- | :--- | :--- |
| `<!-- HASIL_RUN -->` | `Laporan-Praktikum-Week-13.md` bagian 7.3 | Nomor run, status, durasi, tabel step, ukuran artefak |
| `<!-- HASIL_TAG -->` | `Laporan-Praktikum-Week-13.md` bagian 8.2 | Hash commit dan keluaran `git tag -n` |
| `<!-- RINGKASAN_RUN -->` | `README.md` | Ringkasan run dalam satu tabel |
| `<!-- SCREENSHOT -->` | `README.md` | Tabel dan gambar bukti run GitHub |

Gunakan `<img src="..." width="760">` untuk keluaran alat dan `width="320"`
untuk tangkapan layar UI.

---

## 7. Buat tag setelah run hijau

Tag hanya dibuat bila run pada commit Week 13 berstatus success.

```bash
git tag -a v1.1.0 -m "Week 13: CI/CD dan otomatisasi rilis"
git push origin v1.1.0

git tag -n --list "v1.1.0"
git log -1 --format="%H %d"
```

---

## 8. Commit terakhir

```bash
git add _13_week_13_ci_cd_automation
gcommit -m "Week 13 | Lengkapi bukti run GitHub Actions dan tag v1.1.0"
gpush
```

---

## 9. Pekerjaan manual di luar repository

Empat hal ini tidak dapat dikerjakan dari sini dan tidak bergantung pada
pipeline. Rinciannya ada di [`security-review.md`](security-review.md).

| # | Pekerjaan | Alasan tidak otomatis |
| --- | :--- | :--- |
| 1 | Revoke API key lama di Google Cloud Console | Butuh akses akun pemilik proyek |
| 2 | Ganti signing release dengan keystore produksi | Butuh material rahasia yang tidak boleh masuk repository |
| 3 | Simpan material signing di GitHub Actions Secrets | Sama seperti di atas |
| 4 | Uji APK release di perangkat nyata | Butuh perangkat fisik |
