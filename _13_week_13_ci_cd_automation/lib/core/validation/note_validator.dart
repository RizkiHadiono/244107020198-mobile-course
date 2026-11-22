/// Aturan validasi judul catatan.
///
/// Fungsi ini sengaja dibuat murni (tanpa `BuildContext`, tanpa akses
/// database) agar dapat diuji sebagai unit test sekaligus dipakai ulang oleh
/// lapisan domain (`AddNote`) dan lapisan presentasi (dialog tambah catatan).
/// Satu sumber kebenaran berarti pesan error di UI dan di domain tidak pernah
/// berbeda.
library;

/// Batas maksimal panjang judul catatan setelah di-trim.
const int kMaxNoteTitleLength = 120;

/// Mengembalikan `null` bila [value] valid, atau pesan kesalahan bila tidak.
///
/// Aturan:
/// - spasi di awal dan akhir diabaikan saat menghitung panjang,
/// - judul kosong atau hanya berisi spasi ditolak,
/// - judul lebih dari [kMaxNoteTitleLength] karakter ditolak.
String? noteTitleError(String? value) {
  final trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) {
    return 'Judul catatan tidak boleh kosong';
  }
  if (trimmed.length > kMaxNoteTitleLength) {
    return 'Judul catatan maksimal $kMaxNoteTitleLength karakter';
  }
  return null;
}

/// Pintasan boolean untuk [noteTitleError], memudahkan pembacaan di test.
bool isValidNoteTitle(String? value) => noteTitleError(value) == null;
