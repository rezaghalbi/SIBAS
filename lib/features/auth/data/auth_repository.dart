import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/api_guard.dart';
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
      case 'nim_duplicate':
        return 'NIM sudah terdaftar. Gunakan NIM lain atau hubungi admin.';
      case 'weak_password':
        return 'Kata sandi terlalu lemah (minimal 6 karakter).';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Terlalu banyak percobaan. Tunggu beberapa menit lalu coba lagi.';
      case 'signup_disabled':
        return 'Pendaftaran akun sedang dinonaktifkan.';
      default:
        return error.message.isNotEmpty
            ? error.message
            : 'Terjadi kesalahan. Periksa koneksi lalu coba lagi.';
    }
  }
  // Jangan pernah menampilkan toString() mentah ke pengguna.
  return 'Terjadi kesalahan. Periksa koneksi lalu coba lagi.';
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

  /// Email pengguna aktif sudah dikonfirmasi (dipakai gerbang verifikasi).
  bool get isEmailVerified => _client.auth.currentUser?.emailConfirmedAt != null;

  /// Login dengan Email dan Password
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await guardRequest(() async {
        final response = await _client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );

        final user = response.user;
        if (user == null) {
          throw const AuthException('Gagal masuk: Data pengguna tidak ditemukan');
        }

        return await getUserProfile(user.id, emailFallback: user.email);
      });
    } on AuthException {
      rethrow;
    } on JaringanException {
      rethrow;
    } on SesiBerakhirException {
      rethrow;
    } catch (_) {
      // Jangan bocorkan detail internal ke pengguna.
      throw const AuthException(
        'Gagal masuk. Periksa koneksi lalu coba lagi.',
      );
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
  }) {
    return guardRequest(() async {
      try {
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

        return await getUserProfile(user.id, emailFallback: user.email);
      } on AuthException catch (e) {
        // GoTrue membungkus kegagalan trigger `handle_new_user` (NIM duplikat)
        // sebagai unexpected_failure dengan pesan "Database error saving new user",
        // bukan PostgrestException. Petakan agar pengguna tidak melihat pesan mentah.
        final pesan = e.message.toLowerCase();
        if (pesan.contains('duplicate key') ||
            pesan.contains('database error saving new user')) {
          throw const AuthException(
            'NIM atau email sudah terdaftar. Gunakan data lain atau hubungi admin.',
            code: 'nim_duplicate',
          );
        }
        rethrow;
      } on PostgrestException catch (e) {
        // Trigger `handle_new_user` bisa gagal insert profiles karena NIM unik
        // (unique_violation 23505); Supabase melemparkan PostgrestException.
        if (e.code == '23505') {
          throw AuthException(
            'NIM sudah terdaftar. Gunakan NIM lain atau hubungi admin.',
            code: 'nim_duplicate',
          );
        }
        rethrow;
      }
    });
  }

  /// Kirim ulang email verifikasi untuk akun yang belum dikonfirmasi.
  Future<void> resendVerificationEmail(String email) {
    return guardRequest(
      () => _client.auth.resend(type: OtpType.signup, email: email.trim()),
    );
  }

  /// Mengambil data profil dari tabel 'profiles'
  Future<UserModel> getUserProfile(String userId, {String? emailFallback}) {
    return guardRequest(() async {
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
    });
  }

  /// Ganti kata sandi: re-autentikasi dulu agar sesi lama tidak cukup.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) {
      throw const AuthException('Sesi tidak ditemukan. Masuk ulang.');
    }

    await guardRequest(() async {
      // Sandi lama salah → AuthException invalid_credentials dari server.
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    });
  }

  /// Perbarui nama lengkap di tabel `profiles`.
  Future<void> updateFullName(String fullName) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw const AuthException('Sesi tidak ditemukan. Masuk ulang.');
    }

    await guardRequest(() async {
      await _client
          .from('profiles')
          .update({'full_name': fullName.trim()})
          .eq('id', uid);
    });
  }

  /// Logout dari semua perangkat.
  Future<void> signOutEverywhere() {
    return guardRequest(
      () => _client.auth.signOut(scope: SignOutScope.global),
    );
  }

  /// Logout pengguna
  Future<void> signOut() {
    return guardRequest(() => _client.auth.signOut());
  }
}
