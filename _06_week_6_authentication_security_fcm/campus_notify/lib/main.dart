import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';

import 'providers/auth_provider.dart';
import 'messaging/push_service.dart';

// ==========================================
// UI: HALAMAN LOGIN
// ==========================================
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school_rounded, size: 80, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              Text("Campus Notify", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Masuk untuk melihat pengumuman kampus", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 48),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Post-el Mahasiswa',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Kata Sandi',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: isLoading ? null : () => ref.read(authStateProvider.notifier).login('test@mhs.edu', 'password'),
                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Masuk", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// UI: HALAMAN UTAMA (HOME)
// ==========================================
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcements = [
      {'id': '1', 'title': 'Jadwal Perwalian Semester Ganjil', 'date': '24 Okt 2026'},
      {'id': '2', 'title': 'Batas Pembayaran UKT', 'date': '20 Okt 2026'},
      {'id': '3', 'title': 'Kuliah Umum AI & Cyber Security', 'date': '18 Okt 2026'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengumuman', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: announcements.length,
        itemBuilder: (context, index) {
          final item = announcements[index];
          return Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(Icons.campaign_rounded, color: Theme.of(context).colorScheme.onPrimaryContainer),
              ),
              title: Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(item['date']!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/pengumuman/${item['id']}'),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// UI: HALAMAN DETAIL PENGUMUMAN
// ==========================================
class AnnouncementPage extends StatelessWidget {
  const AnnouncementPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pengumuman')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text("ID Referensi: #$id", style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(height: 24),
            Text(
              id == '3' ? 'Kuliah Umum AI & Cyber Security' : 'Pengumuman Penting',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              "Ini adalah detail pengumuman untuk ID $id. Jika Anda dialihkan ke halaman ini dari notifikasi saat aplikasi ditutup (Terminated), maka integrasi getInitialMessage Firebase Messaging Anda telah bekerja dengan sempurna.",
              style: const TextStyle(height: 1.6, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PROVIDER ROUTER & MAIN INITIALIZATION
// ==========================================
final container = ProviderContainer();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final loggedIn = authState.value ?? false;

  return GoRouter(
    redirect: (context, state) {
      final goingLogin = state.matchedLocation == '/login';
      if (!loggedIn && !goingLogin) return '/login';
      if (loggedIn && goingLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/pengumuman/:id',
        builder: (context, state) => AnnouncementPage(id: state.pathParameters['id'] ?? 'unknown'),
      ),
    ],
  );
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  registerBackgroundHandler();

  void navigateFromNotif(String route) {
    container.read(routerProvider).go(route);
  }

  await requestNotificationPermission();
  await initLocalNotifications(navigateFromNotif);
  listenForeground(navigateFromNotif);
  await handleTerminated(navigateFromNotif);

  await subscribeToCampusTopic();

  await initFcmToken(onToken: (token) async {
    debugPrint("Token FCM: ${token.substring(0, 15)}...");
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Campus Notify',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.light),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}