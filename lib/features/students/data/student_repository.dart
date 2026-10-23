import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_guard.dart';
import '../domain/models/student_model.dart';

/// Daftar mahasiswa untuk admin. RLS `profiles_select` mengizinkan admin
/// membaca semua profil; akun terhapus tetap ditandai, bukan disembunyikan.
class StudentRepository {
  final SupabaseClient _client;

  StudentRepository(this._client);

  static const _kolom =
      'id, full_name, nim, email, phone, balance, total_weight, created_at, deleted_at';

  /// Admin mengoreksi nama, NIM, dan nomor WhatsApp mahasiswa.
  /// Peran, saldo, dan status akun tetap terkunci di server.
  Future<StudentModel> ubahMahasiswa({
    required String id,
    required String fullName,
    String? nim,
    String? phone,
  }) {
    return guardRequest(() async {
      final res = await _client.rpc(
        'admin_ubah_mahasiswa',
        params: {
          'p_id': id,
          'p_full_name': fullName,
          'p_nim': nim,
          'p_phone': phone,
        },
      );
      final map = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      return StudentModel.fromJson(map);
    });
  }

  Future<List<StudentModel>> getStudents() {
    return guardRequest(() async {
      final res = await _client
          .from('profiles')
          .select(_kolom)
          .eq('role', 'mahasiswa')
          .order('full_name')
          .limit(500);
      return (res as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(StudentModel.fromJson)
          .toList();
    });
  }
}
