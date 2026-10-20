import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/user_model.dart';

/// Repository untuk penanganan Supabase Auth dan sinkronisasi profil
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  /// Mendapatkan sesi aktif saat ini
  Session? get currentSession => _client.auth.currentSession;

  /// Stream perubahan status autentikasi
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Login dengan Email dan Password
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException('Gagal masuk: Data pengguna tidak ditemukan');
      }

    return await getUserProfile(user.id, emailFallback: user.email);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Gagal masuk: ${e.toString()}');
    }
  }

  /// Registrasi akun baru dengan metadata sesuai contracts.md & prd.md
  /// Payload metadata: {'full_name': ..., 'role': 'mahasiswa'|'admin', 'nim': ...}
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? nim,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'role': role.trim().toLowerCase(),
        'nim': nim?.trim(),
      },
    );

    final user = response.user;
    if (user == null) {
      throw const AuthException('Gagal mendaftar: Data pengguna tidak ditemukan');
    }

    // Jika Supabase mengonfirmasi user langsung atau butuh fallback profil
    try {
      return await getUserProfile(user.id, emailFallback: user.email);
    } catch (_) {
      // Fallback konstruksi dari metadata jika row profile masih dalam proses trigger
      return UserModel(
        id: user.id,
        email: user.email ?? email,
        fullName: fullName,
        nim: nim,
        role: role.toLowerCase(),
      );
    }
  }

  /// Mengambil data profil dari tabel 'profiles'
  Future<UserModel> getUserProfile(String userId, {String? emailFallback}) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) {
      // Fallback jika profile belum terbentuk sempurna
      final user = _client.auth.currentUser;
      final meta = user?.userMetadata ?? {};
      return UserModel(
        id: userId,
        email: user?.email ?? emailFallback ?? '',
        fullName: (meta['full_name'] as String?) ?? 'Pengguna SIBAS',
        nim: meta['nim'] as String?,
        role: (meta['role'] as String?) ?? 'mahasiswa',
      );
    }

    return UserModel.fromJson(data, emailFallback: emailFallback);
  }

  /// Logout pengguna
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
