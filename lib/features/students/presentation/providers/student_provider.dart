import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/student_repository.dart';
import '../../domain/models/student_model.dart';

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository(supabase);
});

final studentsProvider = FutureProvider<List<StudentModel>>((ref) async {
  ref.watch(sessionEpochProvider);
  return ref.watch(studentRepositoryProvider).getStudents();
});
