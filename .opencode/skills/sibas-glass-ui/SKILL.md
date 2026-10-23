---
name: sibas-glass-ui
description: Gunakan saat merancang, mengubah, atau mereview tampilan Flutter SIBAS — memaksa Apple Glassmorphism yang konsisten dengan token AppPalette/AppTheme dan mengacu pada docs/DESIGN_SYSTEM_V2.md serta reference/sibas-glass-2.html
---

# SIBAS Glass UI

Tema resmi: **Apple Glassmorphism**, versi Glass 2.0. Sumber kebenaran berurutan:

1. `docs/DESIGN_SYSTEM_V2.md` — token, tipografi, spacing, shadow, motion, aturan kaca, responsif (mengikat).
2. `AGENTS.md` §2 — ringkasan nilai wajib.
3. `reference/APP FITUR.docx` — aturan bisnis & palet merek.
4. `reference/sibas-glass-2.html` — prototipe visual target.
5. `reference/bank-sampah-poltekk.html` — acuan visual lama (bukan fungsi).

Baca `lib/core/theme/app_palette.dart`, `lib/core/constants/theme.dart`, dan
`lib/core/constants/colors.dart` sebelum menulis widget. Jangan mengarang warna
atau radius baru.

## Keadaan saat ini (per 2026-10-23)

- `AppPalette` (ThemeExtension, 29 token light/dark) dan `AppTheme.darkTheme`
  sudah ada. `AppColors` tetap untuk layar lama, dan **belum** semua layar
  dimigrasi — jangan campur keduanya dalam satu widget kecuali terpaksa.
- `GlassPanel` dipakai 25×. Hanya ada **satu** sumber efek kaca.
- `themeMode` masih `light`; mode sistem dipasang pada tahap 5. Jangan
  mengandalkan `Theme.of(context).brightness` untuk tampilan gelap di layar
  yang belum dimigrasi.
- Tahap yang sudah selesai: 1 (meta web), 2 (token + dark theme), 3
  (`GlassPanel` tone, hero, `ContentWidth`). Berikutnya: 4 (`AdaptiveShell`),
  5 (layar per peran), 6 (polish).

## Token wajib (V2)

| Properti | Nilai |
|---|---|
| Blur | `ImageFilter.blur(sigmaX: 12, sigmaY: 12)`; tone `hero` boleh 8–12 |
| Gradient `subtle` | putih `.20` → `.06` (light), `.13` → `.03` (dark) |
| Gradient `dense` (nav/sheet) | putih `.88` → `.74` (light); `surfaceAlt .92` → `surface .84` (dark) |
| Gradient `hero` (di dalam hero) | putih `.14` → `.08`, border `.25` |
| Border | putih `.24` (subtle), `.16` (dense dark), `1.2` px |
| Inset highlight | 1 px putih di sisi atas |
| Shadow | `sm/md/lg` dari §5; jangan gabung shadow tebal dengan border tebal |
| Radius | `12` ikon/badge, `16` field, `20` kartu, `24` nav, `28` hero/sheet, `pill` 999 |
| Spacing | skala 4 pt: 4, 8, 12, 16, 20, 24, 32, 44; gutter 16 (<900) / 32 (≥900) |
| Lebar konten | `ContentWidth` 1120 px |

Warna dari `AppPalette.of(context)`: `background`, `surface`, `surfaceAlt`,
`elevated`, `text`, `muted`, `faint`, `primary`, `leaf`, `lime`, `mint`,
`mintWash`, `link`, `border`, `borderStrong`, `scrim`, `heroStart/heroMid/
heroEnd/heroInk/heroMuted/heroGlow`, `glassTop/glassBottom/glassBorder/
glassHighlight`. Status: `AppStatusColors.of(brightness)`.

## Komposisi

Satu widget bersama: `lib/core/widgets/glass_panel.dart` (`GlassPanel`).
Urutan lapisan:

```
ClipRRect(radius)
  └─ BackdropFilter(blur 12)
      └─ DecoratedBox(gradient per tone, border token, inset highlight, shadow)
          └─ Padding → child
```

Aturan:
- **Maksimal 1–2 `GlassPanel` per layar.** `BackdropFilter` mahal; di build web
  (CanvasKit) beberapa blur sekaligus menurunkan FPS. Contoh sah: hero + nav.
- `BackdropFilter` butuh latar berisi sesuatu. Tidak ada kaca di dalam kaca,
  tidak ada kaca tanpa konten di belakangnya.
- `disableAnimations` / `prefers-reduced-motion` → render solid tanpa blur.
- Kontras teks wajib ≥ 4.5:1. Uji, jangan asumsikan.
- Jangan pakai `withOpacity` (deprecated sejak Flutter 3.27): `withValues(alpha:)`.
- Jangan bikin `GlassCard`, `GlassContainer`, `GlassBox` terpisah. Satu widget,
  parameter `tone`/`radius`/`padding`/`child`.
- Uang, berat, dan angka rekap memakai `FontFeature.tabularFigures()`.
- Target sentuh ≥ 44 px; tidak ada aksi yang hanya muncul saat hover.
- Konten halaman butuh ruang bawah `96 + safe-area` agar nav mengambang tidak
  menutup aksi terakhir.

## Checklist sebelum lapor selesai

- [ ] Semua nilai blur/gradient/border/shadow/radius berasal dari token di atas.
- [ ] Tidak ada `withOpacity` baru.
- [ ] Tidak ada widget kaca duplikat selain `GlassPanel`.
- [ ] Jumlah `BackdropFilter` per layar ≤ 2.
- [ ] Tone tepat: `subtle` konten, `dense` nav/sheet, `hero` di dalam hero.
- [ ] Teks di atas kaca terbaca (kontras diperiksa, bukan diasumsikan).
- [ ] Dicek di 360, 768, 1280 px; tanpa scroll horizontal.
- [ ] Safe area terpasang di hero, nav, dan sheet.
- [ ] Verifikasi visual lewat **preview Vercel**, bukan lokal — tidak ada SDK
      Flutter di mesin ini. `flutter analyze`/`test` hanya lewat CI.

## Jangan

- Menambah dependency animasi/glass baru. `BackdropFilter` sudah di SDK.
- Menyalin efek dari `reference/*.html` apa adanya; file itu demo localStorage,
  acuan visual saja.
- Mengubah palet `AppColors`/`AppPalette` untuk "biar lebih cantik".
- Menyentuh logika bisnis saat merapikan tampilan.
- Mengubah schema Supabase untuk keperluan tampilan.
