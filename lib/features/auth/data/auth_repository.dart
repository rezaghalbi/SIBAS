import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/user_model.dart';

/// Pesan error auth dalam bahasa Indonesia. Kode `email_not_confirmed` perlu
/// penanganan khusus di UI karena bisa dibereskan lewat kirim ulang email.
String authErrorMessage(Object error) {
  if (error is AuthException) {
    switch (error.code) {
      case 'email_not_confirmed':
        return 'Email belum diverifikasi. Buka tautan di kotak masuk Anda, '
            'atau kirim ulang email verifikasi di bawah.';
      case 'invalid_credentials':
        return 'Email atau kata sandi salah.';
      case 'user_already_exists':
      case 'email_exists':
        return 'Email sudah terdaftar. Silakan masuk.';
      case 'weak_password':
        return 'Kata sandi terlalu lemah (minimal 6 karakter).';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Terlalu banyak percobaan. Tunggu beberapa menit lalu coba lagi.';
      case 'signup_disabled':
        return 'Pendaftaran akun sedang dinonaktifkan.';
      default:
        return error.message;
    }
  }
  return error.toString();
}

/// Benar bila penyebab gagal login adalah email yang belum diverifikasi.
bool isEmailNotConfirmed(Object error) =>
    error is AuthException && error.code == 'email_not_confirmed';

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

  /// Registrasi akun mahasiswa. Role tidak dikirim dari klien: trigger
  /// `handle_new_user` selalu membuat profil dengan role 'mahasiswa'.
  ///
  /// Mengembalikan `null` bila Supabase meminta verifikasi email (belum ada
  /// sesi), sehingga UI bisa menampilkan instruksi cek email.
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String fullName,
    String? nim,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        if (nim != null && nim.trim().isNotEmpty) 'nim': nim.trim(),
      },
    );

    final user = response.user;
    if (user == null) {
      throw const AuthException('Gagal mendaftar: Data pengguna tidak ditemukan');
    }

    if (response.session == null) {
      return null;
    }

    return getUserProfile(user.id, emailFallback: user.email);
  }

  /// Kirim ulang email verifikasi untuk akun yang belum dikonfirmasi.
  Future<void> resendVerificationEmail(String email) async {
    await _client.auth.resend(type: OtpType.signup, email: email.trim());
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
        role: 'mahasiswa',
      );
    }

    return UserModel.fromJson(data, emailFallback: emailFallback);
  }

  /// Logout pengguna
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
