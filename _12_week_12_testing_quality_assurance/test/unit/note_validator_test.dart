import 'package:flutter_test/flutter_test.dart';
import 'package:week12_testing_quality_assurance/core/validation/note_validator.dart';

/// Unit test murni untuk aturan validasi judul catatan.
///
/// Pola yang dipakai adalah Arrange, Act, Assert. Setiap kasus menyiapkan
/// satu nilai masukan, memanggil satu fungsi, lalu memeriksa hasilnya.
void main() {
  group('noteTitleError', () {
    test('menerima judul yang berisi teks biasa', () {
      // Arrange
      const input = 'Belajar Flutter';

      // Act
      final error = noteTitleError(input);

      // Assert
      expect(error, isNull);
      expect(isValidNoteTitle(input), isTrue);
    });

    test('menerima judul dengan spasi di awal dan akhir setelah di-trim', () {
      expect(noteTitleError('  Rapat Proyek  '), isNull);
      expect(isValidNoteTitle('  Rapat Proyek  '), isTrue);
    });

    test('menolak teks kosong', () {
      expect(noteTitleError(''), 'Judul catatan tidak boleh kosong');
      expect(isValidNoteTitle(''), isFalse);
    });

    test('menolak teks yang hanya berisi spasi (kasus tepi)', () {
      expect(noteTitleError('     '), 'Judul catatan tidak boleh kosong');
      expect(isValidNoteTitle('\t \n '), isFalse);
    });

    test('menolak null sebagai masukan yang tidak tersedia', () {
      expect(noteTitleError(null), 'Judul catatan tidak boleh kosong');
      expect(isValidNoteTitle(null), isFalse);
    });

    test('menerima judul tepat pada batas maksimal', () {
      final input = List.filled(kMaxNoteTitleLength, 'a').join();
      expect(input.length, kMaxNoteTitleLength);
      expect(noteTitleError(input), isNull);
    });

    test('menolak judul satu karakter melewati batas (kasus tepi)', () {
      final input = List.filled(kMaxNoteTitleLength + 1, 'a').join();
      expect(
        noteTitleError(input),
        'Judul catatan maksimal $kMaxNoteTitleLength karakter',
      );
    });

    test('menghitung panjang setelah trim, bukan sebelum trim', () {
      // 120 huruf + spasi pembungkus tetap valid karena spasi diabaikan.
      final input = '   ${List.filled(kMaxNoteTitleLength, 'a').join()}   ';
      expect(noteTitleError(input), isNull);
    });

    test('menerima karakter non-ASCII (unicode) sebagai judul valid', () {
      expect(noteTitleError('Rangkuman Bab 3: Analisis Data'), isNull);
      expect(noteTitleError('Catatan Minggu ke-12'), isNull);
    });
  });
}
