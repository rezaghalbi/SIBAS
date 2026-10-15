/// Model kategori sampah SIBAS
class WasteCategoryModel {
  final String id;
  final String name;
  final String unit; // default 'kg'
  final double pricePerKg; // Tarif Rp per kg (bisa 0 jika non-komersial/fokus kg)
  final String? description;

  const WasteCategoryModel({
    required this.id,
    required this.name,
    this.unit = 'kg',
    required this.pricePerKg,
    this.description,
  });

  factory WasteCategoryModel.fromJson(Map<String, dynamic> json) {
    return WasteCategoryModel(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Kategori Sampah',
      unit: (json['unit'] as String?) ?? 'kg',
      pricePerKg: (json['price_per_kg'] != null)
          ? (json['price_per_kg'] as num).toDouble()
          : 0.0,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'price_per_kg': pricePerKg,
      'description': description,
    };
  }
}
