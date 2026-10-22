/// Pengaturan global SIBAS: masa berlaku QR dan kontak admin.
class AppSettingsModel {
  final int qrTtlMinutes;
  final String? contactEmail;
  final String? contactLocation;
  final String? contactHours;

  const AppSettingsModel({
    this.qrTtlMinutes = 120,
    this.contactEmail,
    this.contactLocation,
    this.contactHours,
  });

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    final ttl = json['qr_ttl_minutes'];
    return AppSettingsModel(
      qrTtlMinutes: ttl is num ? ttl.toInt() : 120,
      contactEmail: _teks(json['contact_email']),
      contactLocation: _teks(json['contact_location']),
      contactHours: _teks(json['contact_hours']),
    );
  }

  static String? _teks(Object? value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}
