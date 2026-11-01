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

  Future<List<StudentModel>> getStudents({
    String query = '',
    int limit = 100,
    int offset = 0,
  }) {
    return guardRequest(() async {
      var builder = _client
          .from('profiles')
          .select(_kolom)
          .eq('role', 'mahasiswa');

      final needle = query.trim().replaceAll(RegExp(r'[,()*]'), ' ').trim();
      if (needle.isNotEmpty) {
        final pola = '%$needle%';
        builder = builder.or(
          'full_name.ilike.$pola,'
          'nim.ilike.$pola,'
          'email.ilike.$pola,'
          'phone.ilike.$pola',
        );
      }

      final res = await builder
          .order('full_name')
          .range(offset, offset + limit.clamp(1, 5000) - 1);
      return (res as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(StudentModel.fromJson)
          .toList();
    });
  }

  /// Jumlah total mahasiswa, tanpa menarik seluruh baris.
  Future<int> getStudentCount() {
    return guardRequest(() async {
      final res = await _client
          .from('profiles')
          .select('id')
          .eq('role', 'mahasiswa')
          .count(CountOption.exact);
      return res.count;
    });
  }
}
