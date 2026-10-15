# Visual Identity & UI/UX Design System - SIBAS (Locked Prototype)

## 1. Typography & Typography Scale
- Font Family: `GoogleFonts.plusJakartaSans()`
- Weights: 400 (Regular), 500 (Medium), 600 (SemiBold), 700 (Bold), 800 (ExtraBold)[cite: 2]

## 2. Color Palette (Locked Hex Values)
- Primary Dark: `#095C3B`[cite: 2]
- Primary Main: `#0E7A4F`[cite: 2]
- Primary Light: `#2FA56F`[cite: 2]
- Mint Accent: `#DFF3E8`[cite: 2]
- Mint Soft Background: `#EEF8F2`[cite: 2]
- App Background: `#F3F8F5`[cite: 2]
- Card Surface: `#FFFFFF`[cite: 2]
- Text Primary: `#12201A`[cite: 2]
- Text Muted: `#5F6F67`[cite: 2]
- Border Line: `Color.fromRGBO(15, 60, 40, 0.10)`[cite: 2]

## 3. Status Badges & Chips
- Menunggu Validasi: Text `#B45309`, BG `#FEF3C7`[cite: 2]
- Disetujui / Diterima: Text `#15803D`, BG `#DCFCE7`[cite: 2]
- Ditolak / Kedaluwarsa: Text `#B91C1C`, BG `#FEE2E2`[cite: 2]

## 4. Layout & Component Geometry
- Default Card Radius: `18.0` (`BorderRadius.circular(18)`)[cite: 2]
- Sheet / Modal Top Radius: `28.0` (`BorderRadius.vertical(top: Radius.circular(28))`)[cite: 2]
- Button Radius: `14.0`[cite: 2]
- Input Field Radius: `12.0` dengan border `1.5px solid`[cite: 2]
- Hero Header Gradient: `LinearGradient(colors: [Color(0xFF095C3B), Color(0xFF0E7A4F), Color(0xFF2FA56F)], begin: Alignment.topLeft, end: Alignment.bottomRight)`[cite: 2]
- Card Shadow: `BoxShadow(color: Color.fromRGBO(9, 92, 59, 0.12), blurRadius: 24, offset: Offset(0, 4))`[cite: 2]

## 5. Screen Layout Rules
- Header: Menggunakan Hero Gradient dengan sudut melengkung dan sapaan pengguna[cite: 2].
- Card Saldo: Transparan putih 14% (`Color.fromRGBO(255, 255, 255, 0.14)`) di atas background gradient[cite: 2].
- Bottom Sheet Verification: Menggunakan slide overlay bawah untuk penimbangan, detail transaksi, dan penolakan setoran[cite: 2].
- QR Display Container: Card putih dengan border mint terisolasi, penanda sisa waktu (countdown timer), dan watermark status jika transaksi tidak aktif[cite: 2].