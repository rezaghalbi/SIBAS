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
- `GlassPanel` dipakai 25×. Hanya ada **satu** sumber efek kaca (blur).
- `SurfaceCard` (kaca statis, tanpa blur) ditambahkan sebagai resep tunggal
  untuk kartu konten. Lane layar mengganti kartu putih polos ke widget ini;
  lihat tabel alfa di bawah. Belum semua layar dimigrasi.
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
| Gradient `SurfaceCard` `card` | putih `.72` → `.52` (light), `.06` → `.02` (dark), tanpa blur |
| Gradient `SurfaceCard` `subtle` | putih `.42` → `.28` (light), `.04` → `.015` (dark) |
| Border | **1.0 px semua tone**: `subtle` putih `.20` / `.14`; `dense` `border` / putih `.12`; `hero` putih `.25`; `SurfaceCard` `border` / putih `.14` (`subtle` `.07` / `.10`) |
| Inset highlight | 1 px putih di sisi atas |
| Shadow | `sm/md/lg` dari §5; jangan gabung shadow tebal dengan border tebal (`SurfaceCard` `card` = `sm`, `subtle` tanpa shadow) |
| Radius | `12` ikon/badge, `16` field, `20` kartu, `24` nav, `28` hero/sheet, `pill` 999 |
| Spacing | skala 4 pt: 4, 8, 12, 16, 20, 24, 32, 44; gutter 16 (<900) / 32 (≥900) |
| Lebar konten | `ContentWidth` 1120 px |

Warna dari `AppPalette.of(context)`: `background`, `surface`, `surfaceAlt`,
`elevated`, `text`, `muted`, `faint`, `primary`, `leaf`, `lime`, `mint`,
`mintWash`, `link`, `border`, `borderStrong`, `scrim`, `heroStart/heroMid/
heroEnd/heroInk/heroMuted/heroGlow`, `glassTop/glassBottom/glassBorder/
glassHighlight`. Status: `AppStatusColors.of(brightness)`.

Catatan: `glassBorder` masih `.24`/`.16` di palet, sedangkan `GlassPanel`
tone `subtle` kini memakai putih `.20`/`.14` sesuai aturan border 1.0 px.
Jangan menambah palet baru untuk ini; nilai eksplisit di widget sudah final.

## Komposisi

Dua widget, satu bahasa:

- `lib/core/widgets/glass_panel.dart` (`GlassPanel`) — lapisan **mengambang**
  (hero, nav, sheet). Satu-satunya pemakai `BackdropFilter`.
- `lib/core/widgets/surface_card.dart` (`SurfaceCard`) — semua kartu
  **konten**. Kaca statis: gradien + border + inset highlight, tanpa blur.

Urutan lapisan `GlassPanel`:

```
ClipRRect(radius)
  └─ BackdropFilter(blur 12)
      └─ DecoratedBox(gradient per tone, border 1 px, inset highlight, shadow)
          └─ Padding → child
```

Urutan lapisan `SurfaceCard` (tanpa `BackdropFilter`):

```
DecoratedBox(shadow sm)
  └─ ClipRRect(radius)
      └─ Stack
          ├─ DecoratedBox(gradient per tone, border 1 px)
          │    └─ Padding → child
          └─ inset highlight 1 px di sisi atas
```

Aturan:
- **Maksimal 1–2 `GlassPanel` per layar.** `BackdropFilter` mahal; di build web
  (CanvasKit) beberapa blur sekaligus menurunkan FPS. Contoh sah: hero + nav.
- **Kartu konten tidak memakai `GlassPanel`.** Pakai `SurfaceCard`
  (`tone: card`), panel sekunder di dalamnya `tone: subtle`. `color` hanya
  untuk panel status.
- Jangan membuat `Container`/`DecoratedBox` sendiri untuk kartu konten bila
  `SurfaceCard` cukup; itu sumber tampilan "putih polos" yang tidak seragam.
- `BackdropFilter` butuh latar berisi sesuatu. Tidak ada kaca di dalam kaca,
  tidak ada kaca tanpa konten di belakangnya.
- `disableAnimations` / `prefers-reduced-motion` → `GlassPanel` render solid
  tanpa blur. `SurfaceCard` tidak terpengaruh karena memang tanpa blur.
- Kontras teks wajib ≥ 4.5:1. Uji, jangan asumsikan. `SurfaceCard` light
  kompositnya sekitar `#FCFDFC` di atas `#F3F8F5`; teks `#12201A` aman.
- Jangan pakai `withOpacity` (deprecated sejak Flutter 3.27): `withValues(alpha:)`.
- Jangan bikin `GlassCard`, `GlassContainer`, `GlassBox`, atau `SurfaceBox`
  terpisah. Dua widget di atas sudah final; variasinya lewat parameter
  `tone`/`radius`/`padding`/`color`.
- Uang, berat, dan angka rekap memakai `FontFeature.tabularFigures()`.
- Target sentuh ≥ 44 px; tidak ada aksi yang hanya muncul saat hover.
- Konten halaman butuh ruang bawah `96 + safe-area` agar nav mengambang tidak
  menutup aksi terakhir.

## Checklist sebelum lapor selesai

- [ ] Semua nilai blur/gradient/border/shadow/radius berasal dari token di atas.
- [ ] Tidak ada `withOpacity` baru.
- [ ] Tidak ada widget kaca duplikat selain `GlassPanel` dan `SurfaceCard`.
- [ ] Kartu konten memakai `SurfaceCard`, bukan `Container` berdekorasi sendiri.
- [ ] Jumlah `BackdropFilter` per layar ≤ 2.
- [ ] Tone tepat: `subtle` konten mengambang, `dense` nav/sheet, `hero` di dalam
      hero; `SurfaceCard` `card`/`subtle` untuk kartu dan panel dalam kartu.
- [ ] Semua border 1.0 px, tidak ada 1.2/1.5 pada kaca atau kartu.
- [ ] Teks di atas kaca terbaca (kontras diperiksa, bukan diasumsikan).
- [ ] Dicek di 360, 768, 1280 px; tanpa scroll horizontal.
- [ ] Safe area terpasang di hero, nav, dan sheet.
- [ ] Verifikasi visual lewat **preview Vercel**, bukan lokal — tidak ada SDK
      Flutter di mesin ini. `flutter analyze`/`test` hanya lewat CI.

## Jangan

- Menambah dependency animasi/glass baru. `BackdropFilter` sudah di SDK.
- Menambah `BackdropFilter` pada kartu konten. Blur hanya untuk `GlassPanel`
  di lapisan mengambang.
- Membuat kartu konten dari `Container` + `BoxDecoration` sendiri saat
  `SurfaceCard` bisa dipakai — hasilnya putih polos yang memutus bahasa visual.
- Menyalin efek dari `reference/*.html` apa adanya; file itu demo localStorage,
  acuan visual saja.
- Mengubah palet `AppColors`/`AppPalette` untuk "biar lebih cantik".
- Menyentuh logika bisnis saat merapikan tampilan.
- Mengubah schema Supabase untuk keperluan tampilan.
