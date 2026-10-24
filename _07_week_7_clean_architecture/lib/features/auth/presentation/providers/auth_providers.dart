import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_user.dart';
import '../../domain/usecases/logout_user.dart';

/// Data layer provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

/// Domain layer use case providers
final loginUserProvider = Provider<LoginUser>((ref) {
  return LoginUser(ref.watch(authRepositoryProvider));
});

final logoutUserProvider = Provider<LogoutUser>((ref) {
  return LogoutUser(ref.watch(authRepositoryProvider));
});

/// Auth State
class AuthState {
  const AuthState({this.user, this.isLoading = false, this.errorMessage});

  final User? user;
  final bool isLoading;
  final String? errorMessage;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? errorMessage,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Presentation Auth Notifier
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    state = const AuthState(isLoading: true);
    checkSession();
    return state;
  }

  Future<void> checkSession() async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.getCurrentUser();
    if (result.user != null) {
      state = AuthState(user: result.user, isLoading: false);
    } else {
      state = const AuthState(isLoading: false);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final loginUseCase = ref.read(loginUserProvider);
    final result = await loginUseCase(email: email, password: password);

    if (result.failure != null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.failure!.message,
      );
      return false;
    }

    state = AuthState(user: result.user, isLoading: false);
    return true;
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    final logoutUseCase = ref.read(logoutUserProvider);
    await logoutUseCase();
    state = const AuthState(isLoading: false);
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
