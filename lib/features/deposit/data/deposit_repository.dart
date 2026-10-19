import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/waste_category_model.dart';
import '../../history/domain/models/transaction_model.dart';

/// Repository untuk transaksi setoran sampah dan pemuatan kategori
class DepositRepository {
  final SupabaseClient _client;

  DepositRepository(this._client);

  /// Default kategori fallback jika database kosong / offline
  static final List<WasteCategoryModel> defaultCategories = [
    const WasteCategoryModel(
      id: 'cat_plastik',
      name: 'Sampah Plastik',
      unit: 'kg',
      pricePerKg: 2500,
      description: 'Botol PET, tutup botol, kemasan plastik bersih',
    ),
    const WasteCategoryModel(
      id: 'cat_kertas',
      name: 'Kertas & Karton',
      unit: 'kg',
      pricePerKg: 1800,
      description: 'Kardus, kertas HVS bekas, koran, buku bekas',
    ),
    const WasteCategoryModel(
      id: 'cat_kaleng',
      name: 'Kaleng & Logam',
      unit: 'kg',
      pricePerKg: 5000,
      description: 'Kaleng minuman, aluminium, kawat, besi tipis',
    ),
    const WasteCategoryModel(
      id: 'cat_kaca',
      name: 'Kaca & Botol Beling',
      unit: 'kg',
      pricePerKg: 1000,
      description: 'Botol sirup, kecap, toples kaca utuh tidak pecah',
    ),
    const WasteCategoryModel(
      id: 'cat_jelantah',
      name: 'Minyak Jelantah',
      unit: 'liter/kg',
      pricePerKg: 4000,
      description: 'Minyak goreng bekas dalam jeriken tertutup',
    ),
  ];

  /// Mengambil daftar kategori sampah dari tabel `trash_types`
  Future<List<WasteCategoryModel>> getCategories() async {
    try {
      final response = await _client
          .from('trash_types')
          .select()
          .eq('is_active', true)
          .order('name', ascending: true);

      final list = (response as List<dynamic>)
          .map((item) => WasteCategoryModel.fromJson(item as Map<String, dynamic>))
          .toList();

      if (list.isEmpty) return defaultCategories;
      return list;
    } catch (_) {
      return defaultCategories;
    }
  }

  /// Membuat draf transaksi penyetoran sampah baru
  Future<TransactionModel> createDepositTransaction({
    required String userId,
    required String categoryId,
    required String categoryName,
    required double weightKg,
    required double estimatedAmount,
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 2));

    try {
      final response = await _client
          .from('transactions')
          .insert({
            'mahasiswa_id': userId,
            'trash_type_id': categoryId.startsWith('cat_') ? null : categoryId,
            'weight': weightKg,
            'estimated_amount': estimatedAmount,
            'status': 'PENDING',
            'qr_expires_at': expiresAt.toIso8601String(),
          })
          .select('*, trash_types(name)')
          .single();

      return TransactionModel.fromJson(response);
    } catch (e) {
      // Fallback lokal jika supabase offline / mock data
      return TransactionModel(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        categoryId: categoryId,
        categoryName: categoryName,
        weight: weightKg,
        estimatedAmount: estimatedAmount,
        status: 'PENDING',
        createdAt: now,
        expiresAt: expiresAt,
      );
    }
  }

  /// Mengambil detail satu transaksi berdasarkan ID (untuk QR Screen)
  Future<TransactionModel?> getTransactionById(String transactionId) async {
    try {
      final response = await _client
          .from('transactions')
          .select('*, trash_types(name)')
          .eq('id', transactionId)
          .maybeSingle();

      if (response == null) return null;
      return TransactionModel.fromJson(response);
    } catch (_) {
      return null;
    }
  }
}