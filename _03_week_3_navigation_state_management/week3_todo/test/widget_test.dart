import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Pastikan nama package ini sesuai dengan nama project Anda (week3_todo)
import 'package:week3_todo/main.dart'; 

void main() {
  testWidgets('menambah tugas baru', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    
    // Mengecek state awal harusnya ada teks 'Belum ada tugas'
    expect(find.text('Belum ada tugas'), findsOneWidget);

    // Menekan tombol tambah (+)
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Memasukkan teks tugas
    await tester.enterText(find.byType(TextField), 'Kerjakan PR minggu 3');
    await tester.tap(find.text('Tambah'));
    await tester.pump(); // Memicu rebuild UI

    // Memastikan tugas baru sudah muncul di layar
    expect(find.text('Kerjakan PR minggu 3'), findsOneWidget);
  });
}