# SIBAS Glass 2.0 — Design System

Acuan visual: `reference/sibas-glass-2.html`.
Ruang lingkup: Flutter mobile + web PWA. Dokumen ini tidak mengubah `lib/`, schema, atau dependency.

Status: usulan V2. Implementasi Flutter belum dimulai; temuan terhadap kode saat ini ada di §10.

---

## 1. Prinsip

1. **Hijau memegang kendali.** Deep green, leaf, dan lime tetap identitas. Lime hanya untuk isian/aksen, bukan teks di atas putih.
2. **Kaca hanya untuk lapisan mengambang.** Hero saldo, navigasi, dan sheet. Kartu konten tetap solid agar data mudah dibaca.
3. **Tenang, bukan kosong.** Ruang lega, satu fokus per layar, hierarki lewat ukuran dan bobot, bukan warna acak.
4. **Satu efek, satu sumber.** Semua kaca lewat `GlassPanel`. Tidak ada duplikat `BackdropFilter`.
5. **Selalu ada jalan mundur.** Fallback tanpa blur, reduced motion, dan kontras teks tetap benar di light/dark.
6. **Sentuhan dulu.** Target minimal 44×44 px. Tidak ada aksi yang hanya muncul saat hover.

---

## 2. Token warna

### 2.1 Light

| Token | Nilai | Pakai |
|---|---|---|
| `bg` | `#F3F8F5` | Latar halaman |
| `bg-tint` | `#E8F3EC` | Aurora/glow latar |
| `surface` | `#FFFFFF` | Kartu, rail |
| `surface-2` | `#F7FBF8` | Field, baris sekunder |
| `surface-3` | `#EDF7F1` | Segmen aktif, hover |
| `elevated` | `#FFFFFF` | Sheet, popover |
| `text` | `#12201A` | Teks utama |
| `muted` | `#5C6E65` | Teks sekunder |
| `faint` | `#83948B` | Placeholder, metadata |
| `primary` | `#005746` | Aksi utama, teks merek |
| `primary-2` | `#0A6B4C` | Gradien isian |
| `leaf` | `#16865D` | Fokus, ikon aktif |
| `lime` | `#9BD84A` | Aksen, CTA terang |
| `mint` | `#DFF3E8` | Badge lembut |
| `mint-wash` | `#EAF7F0` | Latar ikon/aktif |
| `link` | `#0E7350` | Tautan |
| `border` | `rgba(15,60,40,.10)` | Garis kartu |
| `border-strong` | `rgba(15,60,40,.17)` | Garis kontrol |
| `scrim` | `rgba(4,28,21,.38)` | Latar sheet |
| `hero-a/b/c` | `#003D32` → `#005746` → `#0C7554` | Gradien hero |
| `hero-ink` | `#FFFFFF` | Teks hero |
| `hero-muted` | `rgba(255,255,255,.74)` | Teks sekunder hero |
| `hero-glow` | `rgba(155,216,74,.34)` | Glow hero |
| `glass-a/b` | `rgba(255,255,255,.20)` → `.06` | Kaca subtle |
| `glass-border` | `rgba(255,255,255,.24)` | Tepi kaca |
| `glass-highlight` | `rgba(255,255,255,.30)` | Inset atas |
| `dense-a/b` | `rgba(255,255,255,.88)` → `.74` | Nav/sheet |
| `nav-a/b` | `rgba(255,255,255,.82)` → `.68` | Nav bawah |

### 2.2 Dark

| Token | Nilai |
|---|---|
| `bg` | `#0A1411` |
| `bg-tint` | `#0E1B16` |
| `surface` | `#111F1A` |
| `surface-2` | `#152720` |
| `surface-3` | `#182D25` |
| `elevated` | `#172A23` |
| `text` | `#ECF6F0` |
| `muted` | `#9CB4A7` |
| `faint` | `#7C9488` |
| `primary` | `#8FE6B8` |
| `primary-2` | `#6FD4A2` |
| `primary-fill-a/b` | `#9BD84A` → `#84C93A` |
| `on-primary-fill` | `#06251B` |
| `leaf` | `#16865D` |
| `link` | `#8FE6B8` |
| `mint-wash` | `#17342A` |
| `border` | `rgba(223,243,232,.09)` |
| `border-strong` | `rgba(223,243,232,.16)` |
| `scrim` | `rgba(0,12,8,.58)` |
| `hero-a/b/c` | `#00261F` → `#004437` → `#0A6249` |
| `hero-muted` | `rgba(255,255,255,.72)` |
| `hero-glow` | `rgba(155,216,74,.20)` |
| `glass-a/b` | `rgba(255,255,255,.13)` → `.03` |
| `glass-border` | `rgba(255,255,255,.16)` |
| `glass-highlight` | `rgba(255,255,255,.18)` |
| `dense-a/b` | `rgba(21,39,32,.92)` → `.84` |
| `nav-a/b` | `rgba(21,39,32,.88)` → `.76` |

Aturan:
- Teks utama minimal 4.5:1 terhadap latar; teks besar minimal 3:1.
- Lime `#9BD84A` tidak dipakai sebagai teks di atas putih. Di dark, CTA lime memakai teks `#06251B`.
- `AppColors` tetap menjadi sumber nilai brand; nilai baru di atas menggantikan varian prototipe lama saat migrasi.

### 2.3 Status

| Status | Light teks / latar / garis | Dark teks / latar / garis |
|---|---|---|
| Disetujui | `#0F6B38` / `#E4F6EA` / `rgba(15,107,56,.18)` | `#8FE6B8` / `rgba(22,134,93,.18)` / `rgba(143,230,184,.16)` |
| Menunggu | `#8A4B08` / `#FCF1DA` / `rgba(138,75,8,.16)` | `#F2CD8A` / `rgba(180,120,30,.18)` / `rgba(242,205,138,.16)` |
| Ditolak | `#9E1B1B` / `#FBE6E6` / `rgba(158,27,27,.16)` | `#F6A6A6` / `rgba(185,28,28,.18)` / `rgba(246,166,166,.16)` |
| Netral/Kedaluwarsa | `#5C6E65` / `#EDF2EF` / `border` | `#A8BDB2` / `rgba(223,243,232,.07)` / `border` |

Pil status selalu memakai titik 5 px + teks, bukan warna saja. Jangan mengandalkan warna untuk menyampaikan status.

---

## 3. Tipografi

Web memakai system stack Apple agar terasa native:

```css
-apple-system, BlinkMacSystemFont, "SF Pro Text", "Plus Jakarta Sans", "Segoe UI", sans-serif
```

Flutter tetap memakai `GoogleFonts.plusJakartaSans()` sebagai font utama; tambahkan `fontFamilyFallback` system agar web/desktop tidak terasa asing. Keputusan font final ada di §12.

| Peran | Ukuran | Bobot | Tracking |
|---|---|---|---|
| Hero display | `clamp(27px, 7vw, 38px)` | 750 | `-.035em` |
| Judul halaman | `clamp(26px, 5vw, 34px)` | 750 | `-.035em` |
| Judul sheet | 21 px | 750 | `-.03em` |
| Judul seksi | 15.5 px | 750 | `-.015em` |
| Body | 13–15 px | 400–500 | 0 |
| Metadata | 11–12 px | 500–600 | `.01em` |
| Label mikro | 9.5–10.5 px | 800 | `.08–.14em`, uppercase |

- Line-height body 1.5; display 1.06–1.1.
- Semua angka uang/berat memakai `font-variant-numeric: tabular-nums` (Flutter: `FontFeature.tabularFigures()`).
- Maksimal 48–52 karakter per baris teks penjelas.

---

## 4. Spacing, grid, radius

Skala 4 pt: `4, 8, 12, 16, 20, 24, 32, 44`.

- Gutter: `clamp(16px, 4vw, 32px)`.
- Lebar konten: `1120px`; rail desktop `268px`; rail sticky `100dvh`.
- Jarak antar seksi: 22–28 px; dalam kartu 12–16 px.
- Ruang bawah halaman: `96px + env(safe-area-inset-bottom)` agar nav mengambang tidak menutup konten.
- Target sentuh: minimal 44×44 px; jarak antar target minimal 8 px.

| Radius | Nilai | Pakai |
|---|---|---|
| `r-12` | 12 px | Ikon kecil, badge |
| `r-16` | 16 px | Field, baris, kartu dalam |
| `r-20` | 20 px | Kartu, panel |
| `r-24` | 24 px | Nav bawah |
| `r-28` | 28 px | Hero, sheet |
| `pill` | 999 px | Chip, segmen, status |

Catatan migrasi: tema Flutter saat ini memakai kartu 18, field 12, tombol 14, sheet 28. V2 menetapkan kartu 20 dan field 16; tombol tetap 14.

---

## 5. Shadow

Light:

- `sm`: `0 1px 2px rgba(0,55,40,.04), 0 8px 24px -14px rgba(0,55,40,.16)`
- `md`: `0 2px 6px rgba(0,55,40,.05), 0 22px 44px -24px rgba(0,55,40,.24)`
- `lg`: `0 8px 24px -12px rgba(0,55,40,.16), 0 36px 72px -36px rgba(0,55,40,.30)`
- `hero`: `0 20px 48px -24px rgba(0,60,45,.50)`

Dark: bayangan hitam 0.60–0.85 + inset highlight `rgba(255,255,255,.03–.05)`.

Aturan: bayangan hanya untuk pemisahan lapisan. Kartu konten memakai border tipis, bukan bayangan besar. Jangan gabungkan shadow tebal dengan border tebal.

---

## 6. Motion

| Token | Durasi | Pakai |
|---|---|---|
| `dur-1` | 160 ms | Tekan, hover, fokus |
| `dur-2` | 260 ms | Masuk layar, buka panel |
| `dur-3` | 300 ms | Sheet |
| `dur-4` | 320 ms | Hero/entrance |
| `ease-out` | `cubic-bezier(.22,1,.36,1)` | Semua transisi utama |
| `ease-soft` | `cubic-bezier(.4,0,.2,1)` | Glow lambat |

- Entrance halaman: opacity 0→1 + `translateY(8–12px)`, stagger 40–60 ms.
- Tekan: `scale(.98)` maksimal; tidak memakai bounce.
- Sheet: slide dari bawah 300 ms + scrim fade 260 ms.
- Animasi hanya `transform`/`opacity`; hindari animasi `height`, `top`, atau `filter`.
- `prefers-reduced-motion: reduce`: matikan translate/scale/glow, sisakan fade ≤120 ms. Flutter memakai `MediaQuery.disableAnimations`.

---

## 7. Aturan kaca

### 7.1 Boleh / tidak

| Boleh | Tidak |
|---|---|
| Hero saldo di atas gradien hero | Blur pada kartu riwayat, form, tabel |
| Nav bawah / rail mengambang | Kaca di dalam kaca |
| Sheet + scrim | Kaca penuh layar |
| Panel ringkasan yang menutupi konten | Kaca tanpa konten di belakangnya |

Kartu konten tetap "kaca" secara visual, tetapi lewat `SurfaceCard` statis — bukan `BackdropFilter`.

Maksimal **1–2 `BackdropFilter` per layar**. Contoh sah: hero + nav = 2; sheet + nav di belakang scrim = 2. Rail desktop solid, tanpa blur.

### 7.2 Resep

| Tone | Light | Dark | Blur |
|---|---|---|---|
| `subtle` | putih .20 → .06, border putih .20 | putih .13 → .03, border putih .14 | 12 |
| `dense` (nav/sheet) | putih .88 → .74, border `border` | `#152720` .92 → `#111F1A` .84, border putih .12 | 12 |
| `hero` (dalam hero) | putih .14 → .08, border putih .25 | sama | 8–12 |

Semua tone memakai inset highlight 1 px di atas dan shadow luar rendah. Radius mengikuti §4. `tint` hanya untuk variasi terkontrol, bukan warna acak.

**Border semua kaca dan kartu: 1.0 px** (seragam, tipis). Nilai 1.2 px pada versi awal dokumen ini sudah tidak berlaku.

#### 7.2.1 `SurfaceCard` — kaca statis untuk kartu konten

Semua kartu konten memakai `lib/core/widgets/surface_card.dart` (`SurfaceCard`) agar bahasa visualnya sama di seluruh halaman tanpa menambah `BackdropFilter`:

| Tone | Light | Dark | Shadow |
|---|---|---|---|
| `card` | putih .72 → .52, border `border` | putih .06 → .02, border putih .14 | `sm` |
| `subtle` | putih .42 → .28, border `border` @ .07 | putih .04 → .015, border putih .10 | tanpa |

`color:` hanya mengganti lapisan permukaan (mis. panel status), border dan shadow tetap netral.

### 7.3 Fallback

- Tanpa dukungan `backdrop-filter`: ganti ke solid `#07493A` (di atas hero) atau `surface` (nav/sheet).
- `prefers-reduced-motion` / `disableAnimations`: jangan blur; pakai solid dengan opasitas .92–.96 agar teks tetap terbaca.
- Jangan letakkan teks penting di atas kaca tipis tanpa lapisan kontras.
- Web: sertakan `-webkit-backdrop-filter` **dan** `backdrop-filter`.

Catatan: `AGENTS.md` menyebut tint `0.15 → 0.05`; V2 memakai `.20 → .06` untuk kontras teks di hero. Perbarui aturan repo setelah disetujui.

---

## 8. Responsif

| Breakpoint | Perubahan |
|---|---|
| `<600px` | Nav bawah mengambang; hero bell disembunyikan; kategori 2 kolom; konten 1 kolom |
| `≥600px` | Kategori 3 kolom; gutter lebih lega; hero bell tampil |
| `≥900px` | Rail 268 px menggantikan nav bawah; sheet terpusat; konten maksimal 1120 px |
| `≥1024px` | Form setor + ringkasan dua kolom |
| `≥1200px` | Ukuran display hero naik; gutter 32 px |

Wajib diuji pada 360, 768, 1280 px, light + dark:

- `document.documentElement.scrollWidth === innerWidth` (tanpa scroll horizontal halaman).
- Chip filter boleh berada di scroller horizontal sendiri.
- Tidak ada teks terpotong pada nama kategori, nominal, dan status.
- Nav bawah tidak menutup aksi terakhir.

---

## 9. Checklist Safari / iOS / PWA

- [ ] `web/index.html` **belum** punya viewport meta. Tambahkan:
  `<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">`
- [ ] `viewport-fit=cover` + `env(safe-area-inset-top/bottom/left/right)` pada hero, nav, sheet.
- [ ] `100dvh` dengan fallback `100vh` untuk layout penuh layar.
- [ ] `-webkit-backdrop-filter` di samping `backdrop-filter`; fallback `@supports not`.
- [ ] `theme-color` light `#F3F8F5` dan dark `#0A1411` lewat `media="(prefers-color-scheme: dark)"`. Saat ini hanya satu `#005746`.
- [ ] Input minimal 16 px agar Safari tidak auto-zoom.
- [ ] Target sentuh ≥44 px; jangan mengandalkan `:hover`.
- [ ] `:focus-visible` terlihat; jangan hilangkan outline tanpa pengganti.
- [ ] `apple-mobile-web-app-status-bar-style` sudah `black-translucent`; verifikasi kontras status bar di hero.
- [ ] `prefers-reduced-motion` dimatikan animasi glow/translate.
- [ ] Uji iOS Safari + mode standalone PWA, bukan hanya Chrome.
- [ ] Nav bawah tidak bertabrakan dengan home indicator; `padding-bottom` memakai safe area.

---

## 10. Pemetaan Flutter

### 10.1 Struktur target

```
lib/core/theme/
  app_palette.dart          # ThemeExtension + light/dark
  app_theme.dart            # AppTheme.light / AppTheme.dark
  page_transitions.dart     # SibasPageTransitionsBuilder
lib/core/widgets/
  glass_panel.dart          # tone: subtle | dense | hero
  content_width.dart
  adaptive_shell.dart       # bottom nav ↔ NavigationRail
```

`AppColors` tetap ada untuk konstanta brand mentah; layar baru membaca `AppPalette.of(context)`.

### 10.2 `AppPalette` (ThemeExtension)

```dart
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.backgroundTint,
    required this.surface,
    required this.surfaceAlt,
    required this.elevated,
    required this.text,
    required this.muted,
    required this.faint,
    required this.primary,
    required this.onPrimary,
    required this.leaf,
    required this.lime,
    required this.mint,
    required this.mintWash,
    required this.link,
    required this.border,
    required this.borderStrong,
    required this.scrim,
    required this.heroStart,
    required this.heroMid,
    required this.heroEnd,
    required this.heroInk,
    required this.heroMuted,
    required this.heroGlow,
    required this.glassTop,
    required this.glassBottom,
    required this.glassBorder,
    required this.glassHighlight,
  });

  final Brightness brightness;
  final Color background, backgroundTint, surface, surfaceAlt, elevated;
  final Color text, muted, faint;
  final Color primary, onPrimary, leaf, lime, mint, mintWash, link;
  final Color border, borderStrong, scrim;
  final Color heroStart, heroMid, heroEnd, heroInk, heroMuted, heroGlow;
  final Color glassTop, glassBottom, glassBorder, glassHighlight;

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>()!;

  // Token tidak diubah per subtree; cukup satu instance per tema.
  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < .5 ? brightness : other.brightness,
      background: c(background, other.background),
      surface: c(surface, other.surface),
      // ...ulangi pola Color.lerp untuk setiap field.
    );
  }
}
```

Isi `AppPalette.light` / `.dark` memakai nilai §2. Status tetap di `AppStatusColors` (dua set konstanta) karena tidak ikut animasi tema.

### 10.3 `AppTheme.light` / `AppTheme.dark`

```dart
static ThemeData get light => _build(AppPalette.light);
static ThemeData get dark => _build(AppPalette.dark);

static ThemeData _build(AppPalette p) => ThemeData(
  useMaterial3: true,
  brightness: p.brightness,
  scaffoldBackgroundColor: p.background,
  extensions: [p],
  colorScheme: ColorScheme(
    brightness: p.brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    secondary: p.leaf,
    onSecondary: Colors.white,
    error: AppStatusColors.of(p.brightness).badText,
    onError: Colors.white,
    surface: p.surface,
    onSurface: p.text,
  ),
  // cardTheme, inputDecorationTheme, bottomSheetTheme memakai p.*
);
```

`main.dart`:

```dart
theme: AppTheme.light,
darkTheme: AppTheme.dark,
themeMode: ref.watch(themeModeProvider),
```

`ThemeMode.system` dapat dikirim lebih dulu. Pilihan manual butuh penyimpanan; lihat §12.

### 10.4 `GlassPanel` tone

```dart
enum GlassTone { subtle, dense, hero }

const GlassPanel({
  ...
  this.tone = GlassTone.subtle,
  this.tint,
});
```

Resolusi warna di `build`:

```dart
final p = AppPalette.of(context);
final top = switch (tone) {
  GlassTone.subtle => p.glassTop,
  GlassTone.dense => p.brightness == Brightness.dark
      ? p.surfaceAlt.withValues(alpha: .92)
      : Colors.white.withValues(alpha: .88),
  GlassTone.hero => Colors.white.withValues(alpha: .14),
};
// Gradien bawah dan border mengikuti tabel 7.2; tone dense memakai radius 24.
```

Pertahankan perilaku sekarang: `disableAnimations` → solid, tanpa `BackdropFilter`. `blurSigma` 12 untuk subtle, 8–12 untuk hero. Jangan menambah `BackdropFilter` baru di widget lain.

### 10.5 `ContentWidth`

```dart
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 1120});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final gutter = w >= 900 ? 32.0 : 16.0;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: child,
        ),
      ),
    );
  }
}
```

### 10.6 `AdaptiveShell` / `NavigationRail`

`_NavScaffold` di `app_router.dart` diganti isi `build`-nya:

- `<900px`: `Scaffold(extendBody: true, body: shell, bottomNavigationBar: AppBottomNav(...))`.
- `≥900px`: `Row(SizedBox(width: 268, child: _Rail(...)), Expanded(child: shell))`; rail solid `p.surface`, border kanan, sticky, tanpa blur.
- Indeks 2 (Tarik) tidak pindah tab: buka `showModalBottomSheet` di atas tab aktif. Route `/tarik` tetap ada untuk deep link/fallback.
- `NavigationRail` hanya jika item 5 muat; label selalu tampil, ikon 20–22 px.
- `pendingCount` tetap dari `adminMetricsProvider` untuk badge admin.

### 10.7 Page transition

```dart
class SibasPageTransitionsBuilder extends PageTransitionsBuilder {
  const SibasPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return child;
    }
    final curved = CurvedAnimation(
      parent: animation,
      curve: const Cubic(.22, 1, .36, 1),
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(.045, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
```

Daftarkan untuk semua platform. Hapus `CupertinoPageTransitionsBuilder` setelah builder ini dipakai.

### 10.8 Hero saldo

- Hero adalah kartu inset radius 28, margin gutter, gradient `150deg` + radial highlight, shadow `hero`.
- Panel saldo di dalam hero memakai `GlassPanel(tone: GlassTone.hero)`; hanya satu blur di hero.
- Aksi cepat menumpuk di tepi bawah hero (`margin-top` negatif), bukan di dalam kaca.
- Hero tidak lagi full-bleed; `HeroHeader` yang sekarang menempel ke atas layar diganti komponen ini.
- Brand dan tombol hero turun ke header biasa di mobile; bell disembunyikan `<600px`.
- Teks hero selalu putih; jangan mewarisi `AppColors.textPrimary` yang hardcoded.

### 10.9 Reduced motion

- `GlassPanel` sudah mematikan blur saat `MediaQuery.disableAnimations`.
- `SibasPageTransitionsBuilder` mengembalikan `child` langsung.
- Glow hero, stagger, dan parallax dimatikan; hanya fade ≤120 ms.
- Hormati juga `MediaQuery.highContrast`? Tidak wajib; jangan menambah kompleksitas sebelum ada keluhan.

---

## 11. Migrasi bertahap

| Tahap | Isi | File utama | Gate |
|---|---|---|---|
| 0 | Baseline screenshot 360/768/1280, light/dark | — | Simpan bukti |
| 1 | Meta web: viewport, theme-color media, safe area | `web/index.html` | CI `Analyze & Test` |
| 2 | Token + `AppPalette` + dark theme; `ThemeMode` dipegang `light` sampai tahap 5 | `core/theme/app_palette.dart`, `theme.dart`, `main.dart` | Light tidak berubah perilaku |
| 2b | Sakelar tema (Terang/Gelap/Sistem) + `SibasColors` untuk layar lama | `theme_mode_controller.dart`, `profile_screen.dart` | Mode gelap dicek di preview |
| 3 | `GlassPanel` tone + hero saldo | `glass_panel.dart`, hero | Maks. 2 blur/layar |
| 4 | `AdaptiveShell` + rail + sheet Tarik | `app_router.dart`, nav | 900 px, deep link |
| 5 | Layar: dashboard, setor, riwayat, profil | `features/*/presentation` | 360/768/1280 |
| 6 | Polish: skeleton, empty, status, reduced motion | lintas fitur | Uji iOS Safari |

Satu tahap = satu PR. Jangan campur refactor tema dengan perubahan perilaku form.

---

## 12. Gap saat ini & keputusan terbuka

| Gap | Bukti | Dampak |
|---|---|---|
| ~~Belum ada palet dark~~ | Selesai: `AppPalette` + `SibasColors` | — |
| ~~Hanya tema light~~ | Selesai: `darkTheme` + `themeModeProvider` | — |
| `GlassPanel` tanpa tone | `glass_panel.dart` hanya `tint` + `isDark` | Nav/sheet rawan kontras |
| Hero lama hardcoded putih, full-bleed | `hero_header.dart` | Tidak cocok dengan hero inset |
| Nav bawah saja | `app_bottom_nav.dart` | Desktop tanpa rail |
| Shell belum adaptif | `_NavScaffold` di `app_router.dart` | Perlu refactor rute |
| Viewport meta hilang | `web/index.html` | Layout iOS salah |
| Tidak ada penyimpanan tema | tanpa `shared_preferences` | Pilihan manual hilang saat reload |

Keputusan yang perlu disetujui:

1. ~~Penyimpanan tema manual~~ — **diputuskan**: `shared_preferences` lewat `themeModeProvider`, pilihan Terang/Gelap/Sistem di Profil.
2. **Model hero**: pertahankan hero inset seperti prototipe (mengganti `HeroHeader` full-bleed) atau hero tetap menempel atas.
3. **Font**: system SF di web saja, atau Plus Jakarta Sans di semua platform. Ini memengaruhi rasa Apple vs konsistensi merek.
4. **Ambang tint kaca**: setujui `.20 → .06` dan perbarui `AGENTS.md` dari `.15 → .05`.

---

## 13. Definition of done

- [ ] `flutter analyze` dan `flutter test` hijau lewat CI.
- [ ] 360 px tanpa scroll horizontal; chip filter hanya scroll di dalam wadahnya.
- [ ] Light + dark lolos cek kontras teks dan status.
- [ ] Maksimal 2 `BackdropFilter` per layar; tidak ada kaca bersarang.
- [ ] Safe area, `100dvh`, `-webkit-backdrop-filter`, fallback blur terpasang.
- [ ] Tidak ada aksi hover-only; target sentuh ≥44 px.
- [ ] Reduced motion mematikan blur/translate.
- [ ] Label “SIBAS Glass 2.0” tetap terlihat kecil di prototipe.
- [ ] Tidak ada perubahan schema atau `service_role` di repo.
