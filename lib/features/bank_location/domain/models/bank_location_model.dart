/// Satu lokasi bank sampah (master data dari RPC `get_locations`).
class BankLocationModel {
  final String id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final bool isActive;

  const BankLocationModel({
    required this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    this.isActive = true,
  });

  /// Koordinat hanya bisa dipakai bila keduanya terisi.
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Teks koordinat 6 desimal untuk ditampilkan, mis. `-7.797068, 110.370529`.
  /// Kosong bila lokasi belum punya koordinat.
  String get koordinatLabel {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return '';
    return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  }

  /// PostgREST mengirim `numeric` sebagai num; nilai string/null tetap
  /// ditoleransi agar satu baris aneh tidak menggagalkan seluruh daftar.
  factory BankLocationModel.fromJson(Map<String, dynamic> json) {
    return BankLocationModel(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'is_active': isActive,
    };
  }

  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }
}
