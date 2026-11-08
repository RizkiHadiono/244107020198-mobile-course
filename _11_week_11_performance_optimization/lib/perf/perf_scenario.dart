import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/services.dart' show TextSelection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/perf/perf_bridge.dart';
import '../core/perf/perf_recorder.dart';
import '../core/perf/perf_scroll_registry.dart';
import '../features/notes/presentation/providers/notes_providers.dart';

/// Skenario profiling yang deterministik.
///
/// Urutannya identik untuk pengukuran "before" dan "after" sehingga
/// perbandingan frame time valid:
///
/// 1. daftar catatan: 10x gulir cepat + kembali ke atas,
/// 2. ketik pencarian karakter demi karakter,
/// 3. buka/tutup halaman detail 5x,
/// 4. buka pengumuman, tunggu gambar, gulir 10x, kembali.
class PerfScenario {
  PerfScenario({required this.ref, required this.router});

  final WidgetRef ref;
  final GoRouter router;

  String _state = 'idle';
  String get state => _state;

  /// Navigasi manual untuk menyiapkan kondisi screenshot.
  void go(String path) {
    final notes = ref.read(notesNotifierProvider).notes;
    if (path.startsWith('/notes/') && notes.isNotEmpty) {
      final id = int.tryParse(path.substring('/notes/'.length));
      final note = notes.firstWhere(
        (n) => n.id == id,
        orElse: () => notes.first,
      );
      router.push(path, extra: note);
      return;
    }
    router.push(path);
  }

  /// Mengisi query pencarian tanpa animasi ketikan (untuk screenshot).
  void search(String query) {
    final field = PerfScrollRegistry.instance.searchField;
    if (field != null && field.text != query) {
      field.text = query;
      field.selection = TextSelection.collapsed(offset: query.length);
    }
    ref.read(notesNotifierProvider.notifier).setSearchQuery(query);
  }

  Future<void> run() async {
    if (_state == 'running') return;
    _state = 'running';
    PerfRecorder.instance.reset();
    PerfRecorder.instance.start();

    try {
      await _wait(900);
      await _scrollNotes();
      await _typeSearch();
      await _navigateDetail();
      await _scrollAnnouncements();
      await _wait(600);
    } finally {
      PerfRecorder.instance.stop();
      _state = 'done';
      publishPerfResult(jsonEncode(PerfRecorder.instance.summary()));
    }
  }

  Future<void> _scrollNotes() async {
    final controller = PerfScrollRegistry.instance.primary;
    if (controller == null || !controller.hasClients) return;

    for (var i = 0; i < 10; i++) {
      final target = math.min(
        controller.position.maxScrollExtent,
        controller.offset + 700,
      );
      if ((target - controller.offset).abs() < 1) break;
      await controller.animateTo(
        target,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
      await _wait(40);
    }
    await controller.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    await _wait(180);
  }

  Future<void> _typeSearch() async {
    final notifier = ref.read(notesNotifierProvider.notifier);
    const query = 'praktikum';
    for (var i = 1; i <= query.length; i++) {
      notifier.setSearchQuery(query.substring(0, i));
      await _wait(70);
    }
    await _wait(250);
    notifier.setSearchQuery('');
    await _wait(250);
  }

  Future<void> _navigateDetail() async {
    for (var i = 0; i < 5; i++) {
      final notes = ref.read(notesNotifierProvider).notes;
      if (notes.isEmpty) return;
      final note = notes[i % notes.length];
      router.push('/notes/${note.id}', extra: note);
      await _wait(280);
      router.pop();
      await _wait(280);
    }
  }

  Future<void> _scrollAnnouncements() async {
    router.push('/announcements');
    await _wait(1200);
    // Beri waktu gambar ter-decode sebelum digulir.
    await _wait(2200);

    final controller = PerfScrollRegistry.instance.primary;
    if (controller != null && controller.hasClients) {
      for (var i = 0; i < 10; i++) {
        final target = math.min(
          controller.position.maxScrollExtent,
          controller.offset + 900,
        );
        if ((target - controller.offset).abs() < 1) break;
        await controller.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
        await _wait(50);
      }
    }
    await _wait(300);
    router.pop();
    await _wait(300);
  }

  Future<void> _wait(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));
}
