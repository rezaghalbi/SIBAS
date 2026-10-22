import 'dart:typed_data';

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
      case 'otp_expired':
      case 'token_expired':
      case 'invalid_token':
      case 'invalid_otp':
        return 'Kode salah atau sudah kedaluwarsa. Minta kode baru.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return 'Terlalu banyak percobaan. Tunggu beberapa menit lalu coba lagi.';
      case 'signup_disabled':
        return 'Pendaftaran akun sedang dinonaktifkan.';
      case 'user_banned':
      case 'banned':
        return 'Akun ini sudah dinonaktifkan. Hubungi admin bila ini keliru.';
      default:
        // Beberapa server hanya mengirim pesan teks tanpa kode.
        if (error.message.toLowerCase().contains('banned')) {
          return 'Akun ini sudah dinonaktifkan. Hubungi admin bila ini keliru.';
        }
        return error.message.isNotEmpty
            ? error.message
            : 'Terjadi kesalahan. Periksa koneksi lalu coba lagi.';
    }
  }
  // Jangan pernah menampilkan toString() mentah ke pengguna.
  return 'Terjadi kesalahan. Periksa koneksi lalu coba lagi.';
}

/// Pesan untuk alur OTP reset sandi: error auth memakai pemetaan khusus,
/// sedangkan gangguan jaringan tetap memakai pesan umum.
String pesanResetSandi(Object error) =>
    error is AuthException ? authErrorMessage(error) : pesanKesalahan(error);

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
    String? phone,
  }) {
    return guardRequest(() async {
      try {
        final response = await _client.auth.signUp(
          email: email.trim(),
          password: password,
          data: {
            'full_name': fullName.trim(),
            if (nim != null && nim.trim().isNotEmpty) 'nim': nim.trim(),
            if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
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

  /// Ubah kata sandi dengan memverifikasi sandi lama lebih dulu.
  Future<void> ubahSandiDenganSandiLama({
    required String lama,
    required String baru,
  }) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) {
      throw const AuthException('Sesi tidak ditemukan. Masuk ulang.');
    }

    try {
      await guardRequest(
        () => _client.auth.signInWithPassword(email: email, password: lama),
      );
    } on AuthException {
      // Server menolak kredensial; jangan teruskan pesan mentahnya.
      throw const AuthException('Kata sandi saat ini salah.');
    }

    await guardRequest(
      () => _client.auth.updateUser(UserAttributes(password: baru)),
    );
  }

  /// Kirim kode OTP atur ulang sandi ke email pengguna.
  ///
  /// Template "Reset Password" di Supabase harus memuat `{{ .Token }}` supaya
  /// email berisi kode 6 digit, bukan tautan.
  Future<void> kirimKodeResetSandi(String email) {
    return guardRequest(
      () => _client.auth.resetPasswordForEmail(email.trim()),
    );
  }

  /// Tukar kode OTP dengan sesi pemulihan yang sah.
  Future<void> verifikasiKodeResetSandi({
    required String email,
    required String kode,
  }) async {
    await guardRequest(
      () => _client.auth.verifyOTP(
        email: email.trim(),
        token: kode.trim(),
        type: OtpType.recovery,
      ),
    );
  }

  /// Simpan sandi baru memakai sesi pemulihan yang sedang aktif.
  Future<void> simpanSandiBaru(String baru) {
    return guardRequest(
      () => _client.auth.updateUser(UserAttributes(password: baru)),
    );
  }

  /// Mengirim permintaan ubah email. Supabase mengirim tautan konfirmasi ke
  /// email baru (dan email lama bila "secure email change" aktif).
  Future<void> changeEmail(String newEmail) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Sesi tidak ditemukan. Masuk ulang.');
    }
    final email = newEmail.trim();
    if (email.toLowerCase() == (user.email ?? '').toLowerCase()) {
      throw const AuthException('Email baru sama dengan email saat ini.');
    }

    await guardRequest(
      () => _client.auth.updateUser(UserAttributes(email: email)),
    );
  }

  /// Ubah nama, NIM, dan nomor WA lewat RPC server (validasi + trigger).
  Future<void> ubahProfil({
    required String nama,
    required String nim,
    required String phone,
  }) async {
    await guardRequest(
      () => _client.rpc('ubah_profil_sendiri', params: {
        'p_full_name': nama.trim(),
        'p_nim': nim.trim(),
        'p_phone': phone.trim(),
      }),
    );
  }

  /// Path avatar_path tersimpan, atau null bila profil belum punya foto.
  Future<String?> _avatarPathTersimpan(String uid) async {
    final data = await _client
        .from('profiles')
        .select('avatar_path')
        .eq('id', uid)
        .maybeSingle();
    return data?['avatar_path'] as String?;
  }

  /// Unggah foto profil ke bucket privat `avatars` lalu simpan path-nya.
  Future<String?> unggahFotoProfil(Uint8List bytes, {required String mime}) {
    return guardRequest(() async {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AuthException('Sesi tidak ditemukan. Masuk ulang.');
      }
      final uid = user.id;

      final ext = switch (mime) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        _ => 'jpg',
      };
      final path = '$uid/foto-${DateTime.now().millisecondsSinceEpoch}.$ext';
      final lama = await _avatarPathTersimpan(uid);

      await _client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mime, upsert: false),
          );
      await _client
          .from('profiles')
          .update({'avatar_path': path}).eq('id', uid);

      // Objek lama tidak wajib terhapus; kegagalan hapus diabaikan.
      if (lama != null && lama != path) {
        try {
          await _client.storage.from('avatars').remove([lama]);
        } catch (_) {
          // Diabaikan: path profil sudah menunjuk foto baru.
        }
      }
      return path;
    });
  }

  /// Hapus foto profil: kosongkan avatar_path lalu buang objeknya.
  Future<void> hapusFotoProfil() {
    return guardRequest(() async {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) {
        throw const AuthException('Sesi tidak ditemukan. Masuk ulang.');
      }

      final lama = await _avatarPathTersimpan(uid);
      await _client
          .from('profiles')
          .update({'avatar_path': null}).eq('id', uid);
      if (lama != null) {
        try {
          await _client.storage.from('avatars').remove([lama]);
        } catch (_) {
          // Diabaikan: avatar_path sudah null, objek boleh tertinggal.
        }
      }
    });
  }

  /// URL bertanda tangan foto profil (1 jam). Null bila belum ada foto atau
  /// gagal; pemanggil tidak perlu menangani error.
  Future<String?> fotoUrlProfil() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    try {
      final path = await _avatarPathTersimpan(uid);
      if (path == null || path.isEmpty) return null;
      return await _client.storage.from('avatars').createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
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

  /// Menandai akun sendiri sebagai terhapus lewat RPC server.
  ///
  /// Server menolak bila saldo masih ada atau ada pengajuan PENDING. Pesan
  /// penolakan sudah berbahasa Indonesia, jadi diteruskan apa adanya.
  Future<void> hapusAkun() async {
    await guardRequest(() => _client.rpc('hapus_akun_sendiri'));
  }
}
