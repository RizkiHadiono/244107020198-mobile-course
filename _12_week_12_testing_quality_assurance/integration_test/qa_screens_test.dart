import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:week12_testing_quality_assurance/main.dart' as app;

/// Skenario khusus dokumentasi: menjalankan alur yang sama seperti
/// `app_test.dart`, lalu mengambil screenshot pada keadaan UI yang penting.
///
/// Dijalankan dengan:
/// ```bash
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/qa_screens_test.dart -d emulator-5554
/// ```
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> resetLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final dbPath = p.join(await getDatabasesPath(), 'clean_notes.db');
    await databaseFactory.deleteDatabase(dbPath);
  }

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
    String? reason,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail(reason ?? 'Elemen tidak muncul dalam ${timeout.inSeconds} detik');
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 700));
  }

  Future<void> shot(String name) async {
    try {
      await binding.takeScreenshot(name);
    } catch (error) {
      debugPrint('Screenshot $name gagal: $error');
    }
  }

  testWidgets('dokumentasi screenshot alur utama', (tester) async {
    await resetLocalState();

    // Surface Flutter perlu dikonversi agar dapat diambil screenshot-nya.
    try {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    } catch (error) {
      debugPrint('convertFlutterSurfaceToImage tidak tersedia: $error');
    }

    app.main();
    await pumpUntilFound(tester, find.byKey(const Key('loginEmailField')));
    await settle(tester);
    await shot('01-login-page');

    await tester.enterText(
      find.byKey(const Key('loginEmailField')),
      'student@polinema.ac.id',
    );
    await tester.enterText(
      find.byKey(const Key('loginPasswordField')),
      'secret123',
    );
    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await pumpUntilFound(
      tester,
      find.byKey(const Key('addNoteFab')),
      reason: 'Halaman catatan tidak terbuka setelah login',
    );
    await settle(tester);
    await shot('02-notes-list');

    // Dialog dengan validasi judul kosong.
    await tester.tap(find.byKey(const Key('addNoteFab')));
    await pumpUntilFound(tester, find.byKey(const Key('noteTitleField')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('noteSaveButton')));
    await tester.pump(const Duration(milliseconds: 300));
    await shot('03-validation-error');

    // Isi form lalu simpan.
    await tester.enterText(
      find.byKey(const Key('noteTitleField')),
      'Catatan Praktikum Week 12',
    );
    await tester.enterText(
      find.byKey(const Key('noteBodyField')),
      'Pengujian unit, widget, dan integrasi.',
    );
    await tester.pump();
    await shot('04-add-note-form');
    await tester.tap(find.byKey(const Key('noteSaveButton')));
    await pumpUntilFound(
      tester,
      find.text('Catatan Praktikum Week 12'),
      reason: 'Catatan baru tidak muncul di daftar',
    );
    await settle(tester);
    await shot('05-note-added');

    // Detail catatan.
    await tester.tap(find.text('Catatan Praktikum Week 12'));
    await pumpUntilFound(tester, find.text('Edit Catatan'));
    await settle(tester);
    await shot('06-note-detail');

    // Kembali ke daftar, lalu cari kata kunci yang tidak ada.
    await tester.pageBack();
    await settle(tester);
    await tester.enterText(
      find.byKey(const Key('notesSearchField')),
      'zzz-tidak-ada',
    );
    await pumpUntilFound(tester, find.byKey(const Key('notesSearchEmptyState')));
    await settle(tester);
    await shot('07-search-empty-state');

    // Bersihkan pencarian agar tampilan akhir rapi.
    await tester.enterText(find.byKey(const Key('notesSearchField')), '');
    await tester.pump();
  });
}
