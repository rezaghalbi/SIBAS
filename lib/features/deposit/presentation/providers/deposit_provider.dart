import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/supabase_client.dart';
import '../../data/deposit_repository.dart';
import '../../domain/models/waste_category_model.dart';
import '../../../history/domain/models/transaction_model.dart';

final depositRepositoryProvider = Provider<DepositRepository>((ref) {
  return DepositRepository(supabase);
});

/// Provider kategori sampah
final wasteCategoriesProvider = FutureProvider<List<WasteCategoryModel>>((ref) async {
  final repo = ref.watch(depositRepositoryProvider);
  return repo.getCategories();
});

/// Provider detail transaksi tunggal untuk QR Screen
final transactionDetailProvider = FutureProvider.family<TransactionModel?, String>((ref, id) async {
  final repo = ref.watch(depositRepositoryProvider);
  return repo.getTransactionById(id);
});
