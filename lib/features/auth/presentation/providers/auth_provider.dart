import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/supabase_client.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/user_model.dart';

/// Provider instance AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(supabase);
});

/// Provider stream perubahan status sesi autentikasi Supabase
final authStateStreamProvider = StreamProvider<dynamic>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

/// Provider state UserModel pengguna saat ini
final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, AsyncValue<UserModel?>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return CurrentUserNotifier(repo);
});

class CurrentUserNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthRepository _repo;

  CurrentUserNotifier(this._repo) : super(const AsyncValue.loading()) {
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    final session = _repo.currentSession;
    if (session == null) {
      state = const AsyncValue.data(null);
      return;
    }

    try {
      final user = await _repo.getUserProfile(session.user.id, emailFallback: session.user.email);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signIn(email: email, password: password);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? nim,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signUp(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        nim: nim,
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _repo.signOut();
    state = const AsyncValue.data(null);
  }
}
