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
