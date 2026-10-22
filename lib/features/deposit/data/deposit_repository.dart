import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/waste_category_model.dart';
import '../../history/domain/models/transaction_model.dart';

/// Repository untuk transaksi setoran sampah dan pemuatan kategori
class DepositRepository {
  final SupabaseClient _client;

  DepositRepository(this._client);

  /// Daftar kategori sampah aktif dari server. Tanpa harga cadangan: nilai
  /// resmi hanya boleh berasal dari tabel `trash_types`.
  Future<List<WasteCategoryModel>> getCategories() async {
    final response = await _client
        .from('trash_types')
        .select()
        .eq('is_active', true)
        .order('name', ascending: true);

    return (response as List<dynamic>)
        .map((item) => WasteCategoryModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Membuat setoran lewat RPC `create_deposit`.
  /// Kode transaksi, token QR, harga per kg, dan nominal dihitung server.
  Future<TransactionModel> createDepositTransaction({
    required String categoryId,
    required double weightKg,
  }) async {
    final res = await _client.rpc(
      'create_deposit',
      params: {'p_trash_type_id': categoryId, 'p_weight': weightKg},
    );

    return TransactionModel.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Detail satu transaksi untuk layar QR. RLS membatasi ke transaksi milik
  /// pengguna sendiri, jadi tidak perlu RPC khusus mahasiswa.
  Future<TransactionModel?> getTransactionById(String transactionId) async {
    final response = await _client
        .from('transactions')
        .select('*, trash_types(name)')
        .eq('id', transactionId)
        .maybeSingle();

    if (response == null) return null;
    return TransactionModel.fromJson(response);
  }
}
