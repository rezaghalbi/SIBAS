import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

/// Epoch sesi: naik setiap login/logout. Provider yang tidak bergantung pada
/// [currentUserProvider] ikut membuang cache saat nilainya berubah.
final sessionEpochProvider = StateProvider<int>((ref) => 0);

/// Provider state UserModel pengguna saat ini
final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, AsyncValue<UserModel?>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return CurrentUserNotifier(repo, ref);
});

class CurrentUserNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthRepository _repo;
  final Ref _ref;
  StreamSubscription<AuthState>? _authSub;

  CurrentUserNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    _initializeUser();

    // Sesi bisa berakhir di luar aplikasi: token kedaluwarsa atau logout dari
    // tab/perangkat lain. Tanpa langganan ini UI tetap menampilkan pengguna
    // yang sudah tidak punya sesi.
    _authSub = _repo.authStateChanges.listen((authState) {
      if (authState.event == AuthChangeEvent.signedOut) {
        state = const AsyncValue.data(null);
        // Sesi berakhir di luar aplikasi: cache provider lain ikut dibuang.
        if (mounted) _ref.read(sessionEpochProvider.notifier).state++;
        return;
      }
      final session = authState.session;
      if (authState.event == AuthChangeEvent.signedIn &&
          session != null &&
          state.valueOrNull == null) {
        unawaited(_loadProfile(session.user.id, session.user.email));
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _initializeUser() async {
    final session = _repo.currentSession;
    if (session == null) {
      state = const AsyncValue.data(null);
      return;
    }
    await _loadProfile(session.user.id, session.user.email);
  }

  Future<void> _loadProfile(String userId, String? email) async {
    try {
      final user = await _repo.getUserProfile(userId, emailFallback: email);
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
      // Naikkan epoch agar cache provider lain dibuang saat akun berganti.
      if (mounted) _ref.read(sessionEpochProvider.notifier).state++;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<UserModel?> register({
    required String email,
    required String password,
    required String fullName,
    String? nim,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signUp(
        email: email,
        password: password,
        fullName: fullName,
        nim: nim,
      );
      // user == null: pendaftaran berhasil, menunggu verifikasi email.
      state = AsyncValue.data(user);
      return user;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Kirim ulang email verifikasi untuk akun yang belum dikonfirmasi.
  Future<void> resendVerification(String email) async {
    await _repo.resendVerificationEmail(email);
  }

  Future<void> logout() async {
    await _repo.signOut();
    state = const AsyncValue.data(null);
    // Epoch naik: semua cache milik akun sebelumnya dibuang.
    if (mounted) _ref.read(sessionEpochProvider.notifier).state++;
  }
}
