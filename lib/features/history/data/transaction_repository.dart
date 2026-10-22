import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/transaction_model.dart';

/// Repository untuk membaca transaksi riwayat & aktivitas pengguna
class TransactionRepository {
  final SupabaseClient _client;

  TransactionRepository(this._client);

  static const _selectWithRelations =
      '*, profiles:profiles!transactions_mahasiswa_id_fkey(full_name, nim), '
      'trash_types(name, price_per_kg)';

  /// Mengambil transaksi terbaru untuk mahasiswa tertentu.
  /// Error dibiarkan naik agar provider menjadi AsyncError (bukan data palsu).
  Future<List<TransactionModel>> getStudentTransactions(String userId, {int limit = 10}) async {
    final response = await _client
        .from('transactions')
        .select('*, trash_types(name)')
        .eq('mahasiswa_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Detail satu transaksi beserta profil mahasiswa dan jenis sampahnya.
  Future<TransactionModel> getTransactionDetail(String id) async {
    final row = await _client
        .from('transactions')
        .select(_selectWithRelations)
        .eq('id', id)
        .single();

    return TransactionModel.fromJson(row);
  }

  /// Realtime stream transaksi mahasiswa
  Stream<List<Map<String, dynamic>>> streamStudentTransactions(String userId) {
    return _client
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('mahasiswa_id', userId)
        .order('created_at', ascending: false);
  }
}
