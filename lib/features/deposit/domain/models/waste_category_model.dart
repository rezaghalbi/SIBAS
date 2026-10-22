/// Model kategori sampah SIBAS
class WasteCategoryModel {
  final String id;
  final String name;
  final String unit; // default 'kg'
  final double pricePerKg; // Tarif Rp per kg (bisa 0 jika non-komersial/fokus kg)
  final String? description;
  final String? imagePath; // Path objek di bucket trash-type-images.

  const WasteCategoryModel({
    required this.id,
    required this.name,
    this.unit = 'kg',
    required this.pricePerKg,
    this.description,
    this.imagePath,
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
      imagePath: json['image_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'price_per_kg': pricePerKg,
      'description': description,
      if (imagePath != null) 'image_path': imagePath,
    };
  }
}
