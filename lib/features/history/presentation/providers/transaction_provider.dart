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

/// Detail satu transaksi sebagai baris mentah (Map) untuk layar detail.
///
/// `TransactionModel` membuang `verified_at` dan nama verifikator, padahal
/// layar detail butuh keduanya. Jadi query diambil langsung dengan join
/// `profiles` lewat FK `transactions_verified_by_fkey`. Null bila tidak ada.
final transactionDetailByIdProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  if (id.isEmpty) return null;

  return supabase
      .from('transactions')
      .select(
        '*, verifier:profiles!transactions_verified_by_fkey(full_name), '
        'trash_types(name, price_per_kg)',
      )
      .eq('id', id)
      .maybeSingle();
});
