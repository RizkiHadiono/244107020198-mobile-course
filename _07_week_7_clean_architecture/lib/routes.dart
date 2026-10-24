import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/notes/domain/entities/note.dart';
import 'features/notes/presentation/pages/note_detail_page.dart';
import 'features/notes/presentation/pages/notes_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/notes',
    redirect: (BuildContext context, GoRouterState state) {
      if (authState.isLoading) return null;

      final isLoggingIn = state.matchedLocation == '/login';
      final isLoggedIn = authState.isAuthenticated;

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }
      if (isLoggedIn && isLoggingIn) {
        return '/notes';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/notes',
        builder: (context, state) => const NotesPage(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final noteExtra = state.extra as Note?;
              if (noteExtra != null) {
                return NoteDetailPage(note: noteExtra);
              }
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return NoteDetailPage(
                note: Note(
                  id: id,
                  title: 'Catatan #$id',
                  body: '',
                  updatedAt: DateTime.now(),
                ),
              );
            },
          ),
        ],
      ),
    ],
  );
});
