# Strategi Pengujian Week 12

Dokumen ini menjelaskan **mengapa** pengujian disusun seperti ini, bukan hanya
apa yang diuji. Tujuannya agar keputusan dapat ditinjau ulang saat aplikasi
berkembang.

---

## 1. Pembagian lapisan pengujian

| Lapis | Yang diperiksa | Biaya | Berkas |
| :--- | :--- | :--- | :--- |
| Unit | Satu fungsi atau satu use case, tanpa merender UI | Paling murah, cepat, stabil | `test/unit/` |
| Widget | Tampilan dan interaksi satu halaman | Sedang, perlu `pumpWidget` | `test/widget/` |
| Integrasi | Alur utuh pada perangkat, plugin asli | Paling mahal, perlu emulator | `integration_test/` |

Aturan pembagian yang dipakai: **semakin murah sebuah lapis, semakin banyak
perilaku yang sebaiknya diuji di sana**. Kasus tepi dan kombinasi masukan
ditempatkan di unit test, bukan di integration test, karena integration test
yang menjalankan puluhan variasi akan lambat dan rapuh.

---

## 2. Kode yang dirancang agar mudah diuji

Sebelum menulis test, ada tiga perubahan pada kode produksi. Perubahan ini
bukan sekadar demi test: ketiganya memperbaiki desain.

### 2.1 Validasi dipisah menjadi fungsi murni

`lib/core/validation/note_validator.dart` menyediakan:

```dart
String? noteTitleError(String? value);
bool isValidNoteTitle(String? value);
```

Fungsi ini tidak mengenal `BuildContext`, database, atau jaringan. Dua
konsumen memakainya:

- `AddNote` (lapisan domain) mengembalikan `ValidationFailure` dengan pesan
  yang sama,
- `AddNoteDialog` dan `NoteDetailPage` (lapisan presentasi) menampilkan
  `errorText` di dalam form.

Sebelumnya aturan hanya hidup di `AddNote`, sehingga pengguna baru melihat
pesan setelah repository dipanggil. Sekarang pesan muncul segera dan tidak
mungkin berbeda antara domain dan UI.

### 2.2 Repository sebagai kontrak

`NoteRepository` adalah `abstract class` dengan delapan operasi. Lapisan
presentasi dan use case hanya bergantung pada kontrak ini, sehingga test dapat
menyuntikkan implementasi apa pun:

```dart
noteRepositoryProvider.overrideWithValue(FakeNoteRepository(...))
```

Tidak ada satu pun unit test atau widget test yang menyentuh SQLite.

### 2.3 `Key` yang stabil

Kontrol yang diuji diberi `Key` eksplisit agar pencarian tidak bergantung pada
teks yang mudah berubah:

| Key | Widget |
| :--- | :--- |
| `addNoteFab` | Tombol Catatan Baru |
| `noteTitleField`, `noteBodyField` | Field pada dialog tambah |
| `noteSaveButton`, `noteCancelButton` | Tombol dialog |
| `notesSearchField` | Kolom pencarian |
| `notesSearchEmptyState` | Empty state pencarian |
| `notesErrorRetry` | Tombol Coba Lagi |
| `noteDetailTitleField`, `noteDetailBodyField` | Field halaman detail |
| `noteDetailSaveButton` | Tombol simpan di detail |
| `loginEmailField`, `loginPasswordField`, `loginSubmitButton` | Form login |

---

## 3. Fake, bukan mock

`test/support/fakes.dart` menyediakan `FakeNoteRepository` dan
`FakeAuthRepository`.

Alasan memilih **fake** (implementasi sederhana yang benar benar berjalan)
daripada **mock** (objek yang hanya merekam pemanggilan):

- Fake menyimpan data di memori, sehingga test dapat memeriksa **keadaan
  akhir** ("apakah catatan benar benar masuk daftar?"), bukan hanya "apakah
  method dipanggil".
- Fake dapat dipakai lintas test tanpa pengaturan rumit.
- Perilaku gagal dapat diubah di tengah test, sehingga skenario "gagal dulu,
  lalu pulih" dapat ditulis:

```dart
repo.fetchFailure = null;             // repository kini sehat
await tester.tap(find.byKey(const Key('notesErrorRetry')));
```

Fake juga menghitung pemanggilan (`addCalls`, `updateCalls`, dan seterusnya).
Penghitung ini dipakai untuk membuktikan hal yang **tidak boleh** terjadi,
misalnya `expect(repo.addCalls, 0)` saat judul kosong: validasi harus menolak
sebelum menyentuh repository.

---

## 4. Daftar skenario

Empat belas skenario berikut mencakup jalur sukses, kasus tepi, dan kegagalan.

### Unit

| # | Skenario | Masukan | Hasil yang diharapkan | Jenis |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Judul berisi teks | `'Belajar Flutter'` | `null` (valid) | Sukses |
| 2 | Judul kosong atau hanya spasi | `''`, `'   '`, `'\t \n '` | `'Judul catatan tidak boleh kosong'` | Kegagalan |
| 3 | Batas panjang judul | 120 dan 121 karakter | Valid pada 120, ditolak pada 121 | Kasus tepi |
| 4 | Panjang dihitung setelah trim | `'   ' + 120 huruf + '   '` | Valid | Kasus tepi |
| 5 | `GetNotes` meneruskan data | Fake berisi 1 catatan | Daftar 1 catatan, `failure == null` | Sukses |
| 6 | `GetNotes` saat database gagal | `LocalFailure('database terkunci')` | `failure` tidak null, daftar kosong | Kegagalan |
| 7 | Pagination di SQLite asli | 25 baris, `limit 20`, `offset 20` | Halaman 1 = 20, halaman 2 = 5, tanpa irisan id | Sukses |
| 8 | Urutan daftar | 3 catatan berurutan waktu | Terbaru di atas | Sukses |
| 9 | Pencarian dengan `%` dan `_` | Judul `'Diskon 50% Spesial'` | Hanya 1 hasil, `_` tidak cocok apa pun | Kasus tepi |
| 10 | Update atau hapus id tidak ada | `id = 999` | `success == false` + `LocalFailure` | Kegagalan |
| 11 | Login kata sandi salah | `'wrongpassword'` | `AuthFailure`, sesi tidak tersimpan | Kegagalan |
| 12 | Penyimpanan sesi gagal dibuka | `getPrefs` melempar exception | `NetworkFailure` atau `LocalFailure` sesuai operasi | Kegagalan |

### Widget

| # | Skenario | Aksi | Hasil yang diharapkan |
| :--- | :--- | :--- | :--- |
| 13 | Tampilan awal dengan data | Buka `NotesPage` | Indikator loading lalu 2 judul catatan tampil |
| 14 | Daftar kosong | Repository tanpa data | Teks `'Belum ada catatan'` tampil |
| 15 | Error lalu pulih | Gagal, tekan Coba Lagi, repository sehat | Pesan error hilang, daftar muncul |
| 16 | Tambah catatan | Isi judul + isi, tekan Simpan | Dialog tertutup, catatan tampil, `addCalls == 1` |
| 17 | Judul hanya spasi | Isi `'     '`, tekan Simpan | `errorText` tampil, dialog tetap terbuka, `addCalls == 0` |
| 18 | Gagal menyimpan | `addFailure` diisi | SnackBar tampil, dialog tetap terbuka |
| 19 | Hapus dengan geser | Geser kartu ke kiri | Catatan hilang dari daftar, `deleteCalls == 1` |
| 20 | Validasi login | Email tanpa `@`, sandi 3 karakter | Pesan validasi tampil, `loginCalls == 0` |
| 21 | Tombol nonaktif saat loading | Tekan Masuk dengan jeda 400 ms | `onPressed == null` selama proses |
| 22 | Detail: simpan perubahan | Ubah judul, tekan Simpan | `updateCalls == 1`, kembali ke daftar |
| 23 | Detail: judul kosong | Kosongkan judul, tekan Simpan | Pesan error, tetap di halaman, `updateCalls == 0` |

### Integrasi

| # | Skenario | Hasil yang diharapkan |
| :--- | :--- | :--- |
| 24 | Alur utama di perangkat | Login, tambah, buka detail, edit, cari, logout berhasil dengan SQLite dan `shared_preferences` asli |

---

## 5. Yang sengaja tidak diuji

Keputusan untuk **tidak** menguji sesuatu juga perlu dicatat agar tidak
dikira terlewat.

| Bagian | Alasan |
| :--- | :--- |
| Panggilan Gemini API sungguhan | Butuh API key, jaringan, dan berbayar. Hasilnya tidak deterministik. Diuji lewat `test/ai_chat_test.dart` dengan klien tiruan. |
| Instrumentasi performa (`lib/core/perf/`) | Hanya aktif saat `--dart-define=PERF_MODE=true` dan bergantung pada `dart:js_interop`. Diukur di Week 11 melalui harness CDP, bukan unit test. |
| Animasi dan transisi | Rapuh terhadap perubahan kecil dan tidak memeriksa perilaku pengguna. |
| Golden test tampilan | Di luar cakupan codelab Week 12, dan belum ada kebutuhan mendesak. |
| Isi `main.dart` (konfigurasi `ImageCache`) | Hanya penyetelan nilai, tidak ada cabang logika. |
| Plugin `sqflite` dan `shared_preferences` itu sendiri | Tanggung jawab paket pihak ketiga. Yang diuji adalah pemakaian kita. |

---

## 6. Prinsip yang dipegang

1. **Uji perilaku, bukan implementasi.** Test mencari teks dan `Key` yang
   dilihat pengguna, tidak memeriksa nama method internal.
2. **Test harus bisa gagal.** Setiap test yang ditulis diverifikasi dengan cara
   membayangkan atau benar benar merusak kode: bila test tetap lulus, test itu
   tidak melindungi apa pun. Contoh nyata: test wildcard `LIKE` gagal pada
   percobaan pertama, dan itulah nilai yang dicari.
3. **Jangan menambah test hanya untuk menaikkan persentase.** Cakupan 74,1 %
   dilaporkan apa adanya, termasuk berkas 0 %.
4. **Tidak ada jeda waktu tetap.** Widget test memakai `pumpAndSettle` atau
   `pump(Duration)`. Integration test memakai `pumpUntilFound` yang memompa
   frame sampai kondisi terpenuhi, bukan `sleep`.
