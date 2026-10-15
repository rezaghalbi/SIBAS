import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/transaction_model.dart';

/// Repository untuk membaca transaksi riwayat & aktivitas pengguna
class TransactionRepository {
  final SupabaseClient _client;

  TransactionRepository(this._client);

  /// Mengambil transaksi terbaru untuk mahasiswa tertentu
  Future<List<TransactionModel>> getStudentTransactions(String userId, {int limit = 10}) async {
    try {
      final response = await _client
          .from('transactions')
          .select('*, waste_categories(name)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List<dynamic>)
          .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Jika terjadi error atau offline, kembalikan list kosong
      return [];
    }
  }

  /// Realtime stream transaksi mahasiswa
  Stream<List<Map<String, dynamic>>> streamStudentTransactions(String userId) {
    return _client
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }
}
