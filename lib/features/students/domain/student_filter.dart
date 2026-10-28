import 'models/student_model.dart';

/// Filter pencarian mahasiswa di klien: nama, NIM, email, atau nomor WA.
List<StudentModel> saringMahasiswa(List<StudentModel> data, String query) {
  final kunci = query.trim().toLowerCase();
  if (kunci.isEmpty) return data;
  return data.where((m) {
    return m.fullName.toLowerCase().contains(kunci) ||
        (m.nim ?? '').toLowerCase().contains(kunci) ||
        m.email.toLowerCase().contains(kunci) ||
        (m.phone ?? '').toLowerCase().contains(kunci);
  }).toList();
}
