import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/transaction_repository.dart';
import '../../domain/models/transaction_model.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(supabase);
});

/// Provider daftar transaksi terbaru mahasiswa (limit 5 untuk dashboard)
final recentTransactionsProvider = FutureProvider<List<TransactionModel>>((ref) async {
  final userState = ref.watch(currentUserProvider);
  final user = userState.valueOrNull;
  if (user == null) return [];

  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getStudentTransactions(user.id, limit: 5);
});
