import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:week_2_declarative_ui_responsive_design/main.dart';

void main() {
  testWidgets('Dashboard satu kolom di layar sempit', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Menggunakan nama class yang sudah kita buat
    await tester.pumpWidget(const AcademicOverviewApp());
    await tester.pumpAndSettle();

    final width = tester.getSize(find.byType(Card).first).width;
    expect(width, lessThan(400));
  });

  testWidgets('Dashboard dua kolom di layar lebar', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Menggunakan nama class yang sudah kita buat
    await tester.pumpWidget(const AcademicOverviewApp());
    await tester.pumpAndSettle();

    final width = tester.getSize(find.byType(Card).first).width;
    expect(width, greaterThan(500));
  });
}