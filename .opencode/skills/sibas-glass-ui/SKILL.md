---
name: sibas-glass-ui
description: Gunakan saat merancang, mengubah, atau mereview tampilan Flutter SIBAS — memaksa Apple Glassmorphism yang konsisten dengan token AppTheme/AppColors dan mengacu pada reference/bank-sampah-poltekk.html
---

# SIBAS Glass UI

Tema resmi: **Apple Glassmorphism**. Sumber kebenaran berurutan:

1. `reference/APP FITUR.docx` — palet & aturan bisnis (mengikat).
2. `AGENTS.md` — nilai glass wajib.
3. `reference/bank-sampah-poltekk.html` — acuan **visual** (bukan fungsi).

Baca dulu `lib/core/constants/theme.dart` dan `lib/core/constants/colors.dart` sebelum menulis widget baru. Jangan mengarang warna atau radius baru.

## Keadaan saat ini (penting)

`grep BackdropFilter lib` = **0 hasil**. Glassmorphism yang diwajibkan `AGENTS.md` belum ada; yang dipakai sekarang hanya putih transparan (`Colors.white.withValues(alpha: 0.18)`), sehingga hasilnya flat. Tugas desain pertama adalah membuat satu sumber efek kaca, bukan menambah variasi baru.

## Token wajib

Ambil dari `AGENTS.md`; jangan diubah tanpa persetujuan:

| Properti | Nilai |
|---|---|
| Blur | `ImageFilter.blur(sigmaX: 12, sigmaY: 12)` |
| Gradient | `white.withValues(alpha: 0.15)` → `white.withValues(alpha: 0.05)` |
| Border | `white.withValues(alpha: 0.2)`, width `1.2` |
| Shadow | blur `20–30`, opacity `0.05–0.1` |
| Radius | `16–24` (kartu utama 18, konsisten dengan `AppTheme.cardRadius`) |

Warna sudah tersedia di `AppColors`: `primaryMain`, `primaryDark`, `mint`, `mintSoftBackground`, `cardSurface`, `textPrimary`, `textMuted`, `borderLine`, `heroCardSurface`, `heroCardBorder`.

## Komposisi

Gunakan satu widget bersama: `lib/core/widgets/glass_panel.dart` (`GlassPanel`). Urutan lapisan:

```
ClipRRect(radius)
  └─ BackdropFilter(blur 12)
      └─ DecoratedBox(gradient putih 0.15→0.05, border putih 0.2/1.2, shadow)
          └─ Padding → child
```

Aturan:
- **Maksimal 1–2 `GlassPanel` per layar.** `BackdropFilter` mahal; di build web (CanvasKit) beberapa blur sekaligus menurunkan FPS. Kalau perlu lebih, ganti sisanya ke gradient statis tanpa blur.
- `BackdropFilter` butuh latar berisi sesuatu. Di atas background polos efeknya tak terlihat — letakkan di atas `HeroHeader`, foto, atau gradien.
- Kontras teks wajib ≥ 4.5:1. Putih 0.85 di atas kaca gelap masih terbaca; teks `textMuted` di atas kaca putih transparan sering gagal — uji, jangan asumsikan.
- Jangan pakai `withOpacity`. API-nya deprecated sejak Flutter 3.27; repo sudah pakai `withValues(alpha:)`.
- Jangan bikin `GlassCard`, `GlassContainer`, `GlassBox` terpisah. Satu widget, parameter radius/padding/child.

## Checklist sebelum lapor selesai

- [ ] Semua nilai blur/gradient/border/shadow berasal dari token di atas.
- [ ] Tidak ada `withOpacity` baru.
- [ ] Tidak ada widget kaca duplikat selain `GlassPanel`.
- [ ] Jumlah `BackdropFilter` per layar ≤ 2.
- [ ] Radius konsisten 16–24 dan serasi dengan `AppTheme.cardRadius`.
- [ ] Teks di atas kaca terbaca (kontras diperiksa, bukan diasumsikan).
- [ ] Dicek di layar sempit (360dp) dan lebar (web ≥ 900dp).
- [ ] Verifikasi visual lewat **preview Vercel**, bukan lokal — tidak ada SDK Flutter di mesin ini.

## Jangan

- Menambah dependency animasi/glass baru. `BackdropFilter` sudah di SDK.
- Menyalin efek dari `reference/*.html` apa adanya; file itu demo localStorage, acuan visual saja.
- Mengubah palet `AppColors` untuk "biar lebih cantik".
- Menyentuh logika bisnis saat merapikan tampilan.
