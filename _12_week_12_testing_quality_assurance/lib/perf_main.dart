import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';

import 'core/perf/perf_bridge.dart';
import 'core/perf/perf_recorder.dart';
import 'features/auth/domain/entities/user.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/notes/presentation/providers/notes_providers.dart';
import 'perf/in_memory_note_repository.dart';
import 'perf/perf_scenario.dart';
import 'routes.dart';

/// Entry point khusus profiling.
///
/// ```bash
/// flutter build web --profile -t lib/perf_main.dart \
///   --dart-define=PERF_MODE=true \
///   --dart-define=PERF_IMAGE_BASE=http://127.0.0.1:8777/img
/// ```
///
/// Perbedaan dengan `lib/main.dart` hanya pada sumber data (repository
/// in-memory dan auth palsu) serta jembatan JS untuk harness. Seluruh widget
/// dan provider yang diukur tetap kode produksi.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final cache = PaintingBinding.instance.imageCache;
  cache.maximumSize = 200;
  cache.maximumSizeBytes = 60 << 20;
  PerfRecorder.instance.start();
  runApp(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(FakeAuthNotifier.new),
        noteRepositoryProvider.overrideWithValue(InMemoryNoteRepository()),
        dirtyNotesCountProvider.overrideWith((ref) async => 0),
      ],
      child: const PerfApp(),
    ),
  );
}

class PerfApp extends ConsumerStatefulWidget {
  const PerfApp({super.key});

  @override
  ConsumerState<PerfApp> createState() => _PerfAppState();
}

class _PerfAppState extends ConsumerState<PerfApp> {
  PerfScenario? _scenario;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      PerfRecorder.instance.markFirstFrame();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final scenario = _scenario ??= PerfScenario(ref: ref, router: router);

    exposePerfBridge(
      onStart: scenario.run,
      onSummary: () => jsonEncode(PerfRecorder.instance.summary()),
      onState: () => scenario.state,
      onNavigate: scenario.go,
      onSearch: scenario.search,
    );

    return MaterialApp.router(
      title: 'Week 11 - Performance Harness',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
      ),
      routerConfig: router,
    );
  }
}

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    user: User(
      id: 'usr_perf',
      name: 'PERF HARNESS',
      email: 'perf@polinema.ac.id',
    ),
  );
}
