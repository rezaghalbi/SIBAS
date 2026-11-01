import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/student_repository.dart';
import '../../domain/models/student_model.dart';

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository(supabase);
});

/// Pencarian dan batas baris daftar mahasiswa (server-side).
final adminStudentQueryProvider = StateProvider<String>((ref) => '');
final adminStudentLimitProvider = StateProvider<int>((ref) => 100);

final studentsProvider = FutureProvider<List<StudentModel>>((ref) async {
  ref.watch(sessionEpochProvider);
  return ref.watch(studentRepositoryProvider).getStudents(
        query: ref.watch(adminStudentQueryProvider),
        limit: ref.watch(adminStudentLimitProvider),
      );
});

/// Jumlah total mahasiswa untuk kartu ringkasan dashboard.
final studentCountProvider = FutureProvider<int>((ref) async {
  ref.watch(sessionEpochProvider);
  return ref.watch(studentRepositoryProvider).getStudentCount();
});
