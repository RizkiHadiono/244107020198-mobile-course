import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:week12_testing_quality_assurance/main.dart' as app;

/// Integration test alur utama aplikasi pada perangkat/emulator.
///
/// Berbeda dengan widget test, di sini seluruh lapisan asli dipakai:
/// `main()`, go_router, Riverpod tanpa override, `shared_preferences`, dan
/// SQLite melalui `sqflite`. Tidak ada fake sama sekali.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Membersihkan sesi dan database agar hasil test tidak bergantung pada
  /// sisa data run sebelumnya.
  Future<void> resetLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final dbPath = p.join(await getDatabasesPath(), 'clean_notes.db');
    await databaseFactory.deleteDatabase(dbPath);
  }

  /// Memompa frame sampai [finder] menemukan sesuatu atau waktu habis.
  ///
  /// Lebih andal daripada `pumpAndSettle` pada perangkat nyata, karena
  /// indikator loading beranimasi terus dan proses I/O butuh waktu nyata.
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

  /// Memberi waktu animasi transisi rute selesai sebelum berinteraksi.
  ///
  /// Tanpa jeda ini, `enterText` dapat mengetuk posisi field saat dialog masih
  /// dalam animasi masuk, sehingga ketukan jatuh ke barrier dan dialog tertutup.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('alur utama: login, tambah, edit, cari, dan logout', (
    tester,
  ) async {
    await resetLocalState();

    // 1. Jalankan aplikasi sungguhan. Sesi kosong berarti diarahkan ke login.
    app.main();
    await pumpUntilFound(tester, find.byKey(const Key('loginEmailField')));
    await settle(tester);
    expect(find.text('Clean Notes App'), findsOneWidget);

    // 2. Login dengan akun demo.
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

    // 3. Tambah catatan baru melalui dialog.
    const judul = 'Catatan Uji Integrasi';
    const judulRevisi = 'Catatan Uji Integrasi Revisi';

    await tester.tap(find.byKey(const Key('addNoteFab')));
    await pumpUntilFound(tester, find.byKey(const Key('noteTitleField')));
    await settle(tester);

    await tester.enterText(find.byKey(const Key('noteTitleField')), judul);
    await tester.enterText(
      find.byKey(const Key('noteBodyField')),
      'Ditulis oleh integration test pada perangkat.',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('noteSaveButton')));
    await pumpUntilFound(
      tester,
      find.text(judul),
      reason: 'Catatan baru tidak muncul di daftar',
    );
    await settle(tester);

    // 4. Buka detail, ubah judul, lalu simpan.
    await tester.tap(find.text(judul));
    await pumpUntilFound(tester, find.text('Edit Catatan'));
    await settle(tester);

    await tester.enterText(
      find.byKey(const Key('noteDetailTitleField')),
      judulRevisi,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('noteDetailSaveButton')));
    await pumpUntilFound(
      tester,
      find.text(judulRevisi),
      reason: 'Judul hasil edit tidak tampil di daftar',
    );
    await settle(tester);

    // 5. Cari catatan hasil edit.
    await tester.enterText(
      find.byKey(const Key('notesSearchField')),
      'Revisi',
    );
    await pumpUntilFound(tester, find.text(judulRevisi));
    expect(find.text(judulRevisi), findsOneWidget);

    // 6. Logout dan kembali ke halaman login.
    await tester.enterText(find.byKey(const Key('notesSearchField')), '');
    await tester.pump();
    await tester.tap(find.byTooltip('Keluar'));
    await pumpUntilFound(
      tester,
      find.text('Masuk ke Akun'),
      reason: 'Tidak kembali ke halaman login setelah logout',
    );
  });
}
