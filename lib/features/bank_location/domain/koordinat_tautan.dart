/// Hasil pembacaan koordinat dari tautan atau teks.
typedef Koordinat = ({String latitude, String longitude});

final _polaAt = RegExp(r'@(-?\d{1,2}\.\d+),(-?\d{1,3}\.\d+)');
final _polaKunci = RegExp(
  r'[?&](?:q|query|ll|center|destination)=(-?\d{1,2}\.\d+),\s*(-?\d{1,3}\.\d+)',
  caseSensitive: false,
);
final _polaPolos = RegExp(
  r'^\s*(-?\d{1,2}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)\s*$',
);

/// Mengambil koordinat dari tautan Google Maps atau teks `lat, long`.
///
/// Mendukung bentuk tautan yang umum dipakai saat berbagi lokasi:
/// `.../@-7.797068,110.370529,17z`, `?q=-7.79,110.37`, `?ll=`, `?center=`,
/// `?destination=`, serta teks polos `-7.797068, 110.370529`.
/// Mengembalikan `null` bila tidak ada pasangan valid.
Koordinat? koordinatDariTautan(String? teks) {
  if (teks == null || teks.trim().isEmpty) return null;

  final bersih = teks.trim();
  final kandidat = <Match?>[
    _polaAt.firstMatch(bersih),
    _polaKunci.firstMatch(bersih),
    _polaPolos.firstMatch(bersih),
  ];

  for (final m in kandidat) {
    if (m == null) continue;
    final lat = double.tryParse(m.group(1) ?? '');
    final lng = double.tryParse(m.group(2) ?? '');
    if (lat == null || lng == null) continue;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;
    return (latitude: _format(lat), longitude: _format(lng));
  }
  return null;
}

/// Enam desimal cukup untuk skala meter dan cocok dengan numeric(9,6).
String _format(double nilai) => nilai.toStringAsFixed(6);
