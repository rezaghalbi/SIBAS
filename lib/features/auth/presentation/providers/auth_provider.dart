import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_client.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/user_model.dart';

/// Pesan saat akun sudah ditandai terhapus di server.
const _pesanAkunTerhapus =
    'Akun ini sudah ditandai terhapus. Hubungi admin bila ini keliru.';

/// Kode error internal agar form login membedakan penolakan akun terhapus.
const _kodeAkunTerhapus = 'akun_terhapus';

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

/// True saat sesi berasal dari tautan pemulihan sandi (lupa sandi).
final passwordRecoveryProvider = StateProvider<bool>((ref) => false);

/// Provider state UserModel pengguna saat ini
final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, AsyncValue<UserModel?>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return CurrentUserNotifier(repo, ref);
});

/// URL bertanda tangan foto profil. Didefinisikan setelah [currentUserProvider]
/// agar tidak circular; notifier membuang cache-nya setiap foto berubah.
final avatarUrlProvider = FutureProvider<String?>((ref) async {
  // Ikut state pengguna supaya URL lama tidak bertahan setelah akun berganti.
  ref.watch(currentUserProvider);
  return ref.watch(authRepositoryProvider).fotoUrlProfil();
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
      if (authState.event == AuthChangeEvent.passwordRecovery) {
        // Jangan timpa state pengguna: sesi pemulihan tetap milik user aktif.
        if (mounted) {
          _ref.read(passwordRecoveryProvider.notifier).state = true;
        }
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
      if (user.deletedAt != null) {
        await _keluarAkunTerhapus();
        // Pemanggil _loadProfile bersifat fire-and-forget, jadi pesan dibawa
        // lewat state error (nilai null) agar tidak menjadi unhandled error.
        state = AsyncValue.error(
          const AuthException(_pesanAkunTerhapus, code: _kodeAkunTerhapus),
          StackTrace.current,
        );
        return;
      }
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Cabut sesi akun terflag, kosongkan state (router kembali ke login), dan
  /// naikkan epoch. Kegagalan signOut diabaikan; sesi lokal tetap dibersihkan.
  Future<void> _keluarAkunTerhapus() async {
    try {
      await _repo.signOut();
    } catch (_) {
      // Diabaikan: yang penting pengguna tidak tetap masuk.
    }
    state = const AsyncValue.data(null);
    if (mounted) _ref.read(sessionEpochProvider.notifier).state++;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signIn(email: email, password: password);
      if (user.deletedAt != null) {
        await _keluarAkunTerhapus();
        // Dilempar agar form login menampilkan pesan; state sudah data(null)
        // sehingga router mengarah ke /login, bukan layar putih.
        throw const AuthException(_pesanAkunTerhapus, code: _kodeAkunTerhapus);
      }
      state = AsyncValue.data(user);
      // Naikkan epoch agar cache provider lain dibuang saat akun berganti.
      if (mounted) _ref.read(sessionEpochProvider.notifier).state++;
    } catch (e, st) {
      // Akun terhapus: state sudah data(null), jangan ditimpa error.
      if (!(e is AuthException && e.code == _kodeAkunTerhapus)) {
        state = AsyncValue.error(e, st);
      }
      rethrow;
    }
  }

  Future<UserModel?> register({
    required String email,
    required String password,
    required String fullName,
    String? nim,
    String? phone,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signUp(
        email: email,
        password: password,
        fullName: fullName,
        nim: nim,
        phone: phone,
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

  /// Simpan perubahan profil lalu segarkan state dan URL foto.
  Future<void> ubahProfil({
    required String nama,
    required String nim,
    required String phone,
  }) async {
    await _repo.ubahProfil(nama: nama, nim: nim, phone: phone);
    await _muatUlangProfil();
  }

  /// Unggah foto profil baru lalu segarkan state dan URL foto.
  Future<void> ubahFotoProfil({
    required Uint8List bytes,
    required String mime,
  }) async {
    await _repo.unggahFotoProfil(bytes, mime: mime);
    await _muatUlangProfil();
  }

  /// Hapus foto profil lalu segarkan state dan URL foto.
  Future<void> hapusFotoProfil() async {
    await _repo.hapusFotoProfil();
    await _muatUlangProfil();
  }

  /// Ubah kata sandi dengan verifikasi sandi lama. State pengguna tidak berubah.
  Future<void> ubahSandiDenganSandiLama({
    required String lama,
    required String baru,
  }) async {
    await _repo.ubahSandiDenganSandiLama(lama: lama, baru: baru);
  }

  /// Kirim tautan reset sandi (lupa sandi) ke email.
  Future<void> kirimTautanResetSandi(String email) =>
      _repo.kirimTautanResetSandi(email);

  /// Simpan sandi baru dari sesi pemulihan lalu keluar dari mode pemulihan.
  Future<void> simpanSandiBaru(String baru) async {
    await _repo.simpanSandiBaru(baru);
    if (mounted) _ref.read(passwordRecoveryProvider.notifier).state = false;
    // Sandi sudah tersimpan; gagal memuat profil tidak boleh tampil sebagai
    // kegagalan atur sandi.
    try {
      await _muatUlangProfil();
    } catch (_) {}
  }

  /// Batalkan mode pemulihan tanpa mengubah sandi.
  void batalPemulihanSandi() {
    if (mounted) _ref.read(passwordRecoveryProvider.notifier).state = false;
  }

  /// Ambil ulang profil dari server agar UI memakai data terbaru.
  Future<void> _muatUlangProfil() async {
    final sesi = _repo.currentSession;
    if (sesi == null) return;

    final user = await _repo.getUserProfile(
      sesi.user.id,
      emailFallback: sesi.user.email,
    );
    if (!mounted) return;

    state = AsyncValue.data(user);
    _ref.invalidate(avatarUrlProvider);
  }

  Future<void> logout() async {
    await _repo.signOut();
    state = const AsyncValue.data(null);
    // Epoch naik: semua cache milik akun sebelumnya dibuang.
    if (mounted) _ref.read(sessionEpochProvider.notifier).state++;
  }
}
