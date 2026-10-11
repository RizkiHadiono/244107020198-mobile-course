import 'package:flutter_test/flutter_test.dart';
import 'package:week7_clean_architecture/core/format.dart';

void main() {
  group('Core Format & Parsing Pure Functions Unit Tests', () {
    test('formatDate menghasilkan string tanggal dan jam yang tepat', () {
      final date = DateTime(2026, 9, 27, 14, 5);
      final result = formatDate(date);
      expect(result, '27 Sep 2026, 14:05');
    });

    test('formatDateShort menghasilkan string tanggal ringkas', () {
      final date = DateTime(2026, 10, 11);
      final result = formatDateShort(date);
      expect(result, '11 Okt 2026');
    });

    test('parseIdFromPath mengekstrak ID integer dari URL route', () {
      expect(parseIdFromPath('/notes/42'), 42);
      expect(parseIdFromPath('/pengumuman/105'), 105);
      expect(parseIdFromPath('/notes/abc'), isNull);
      expect(parseIdFromPath(''), isNull);
    });

    test('sanitizeInput memotong whitespace di awal dan akhir', () {
      expect(sanitizeInput('   Pemrograman Mobile   '), 'Pemrograman Mobile');
      expect(sanitizeInput('\n\t Clean Architecture \n'), 'Clean Architecture');
    });
  });
}
