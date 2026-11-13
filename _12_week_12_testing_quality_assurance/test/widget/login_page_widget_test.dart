import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:week12_testing_quality_assurance/core/failures.dart';
import 'package:week12_testing_quality_assurance/features/auth/presentation/pages/login_page.dart';
import 'package:week12_testing_quality_assurance/features/auth/presentation/providers/auth_providers.dart';

import '../support/fakes.dart';

/// Widget test halaman login: memeriksa validasi masukan dan keadaan loading.
void main() {
  Widget buildSubject(FakeAuthRepository repo) {
    return ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: LoginPage()),
    );
  }

  testWidgets('menampilkan form login dengan nilai awal demo', (tester) async {
    await tester.pumpWidget(buildSubject(FakeAuthRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Clean Notes App'), findsOneWidget);
    expect(find.byKey(const Key('loginEmailField')), findsOneWidget);
    expect(find.byKey(const Key('loginPasswordField')), findsOneWidget);
    expect(find.byKey(const Key('loginSubmitButton')), findsOneWidget);
  });

  testWidgets('email tanpa @ ditolak sebelum memanggil repository', (
    tester,
  ) async {
    final repo = FakeAuthRepository();

    await tester.pumpWidget(buildSubject(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('loginEmailField')),
      'bukan-email',
    );
    await tester.enterText(
      find.byKey(const Key('loginPasswordField')),
      'secret123',
    );
    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pumpAndSettle();

    expect(
      find.text('Format email tidak valid (harus mengandung @)'),
      findsOneWidget,
    );
    expect(repo.loginCalls, 0);
  });

  testWidgets('kata sandi kurang dari 6 karakter ditolak', (tester) async {
    final repo = FakeAuthRepository();

    await tester.pumpWidget(buildSubject(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('loginPasswordField')),
      '123',
    );
    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.text('Kata sandi minimal 6 karakter'), findsOneWidget);
    expect(repo.loginCalls, 0);
  });

  testWidgets('kredensial salah menampilkan pesan kegagalan dari server', (
    tester,
  ) async {
    final repo = FakeAuthRepository(
      loginFailure: const AuthFailure('Email atau kata sandi salah'),
    );

    await tester.pumpWidget(buildSubject(repo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('loginPasswordField')),
      'wrongpassword',
    );
    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pumpAndSettle();

    expect(find.text('Email atau kata sandi salah'), findsOneWidget);
    expect(repo.loginCalls, 1);
    expect(repo.lastEmail, 'student@polinema.ac.id');
  });

  testWidgets('tombol nonaktif selama proses login berlangsung', (
    tester,
  ) async {
    final repo = FakeAuthRepository(
      loginFailure: const AuthFailure('Email atau kata sandi salah'),
      latency: const Duration(milliseconds: 400),
    );

    await tester.pumpWidget(buildSubject(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pump(const Duration(milliseconds: 100));

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('loginSubmitButton')),
    );
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    final afterButton = tester.widget<FilledButton>(
      find.byKey(const Key('loginSubmitButton')),
    );
    expect(afterButton.onPressed, isNotNull);
  });
}
