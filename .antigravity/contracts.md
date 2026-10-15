# Code Contract & Utility Registry

## Database RPC Functions
- `approve_transaction(p_transaction_id UUID, p_admin_id UUID)`
- `reject_transaction(p_transaction_id UUID, p_admin_id UUID, p_reason TEXT)`

## Flutter Shared Components & Utilities
- Color System: `lib/core/constants/colors.dart` -> `AppColors` (Primary #0E7A4F, Dark #095C3B, Mint #DFF3E8, Bg #F3F8F5)
- Theme System: `lib/core/constants/theme.dart` -> `AppTheme` (GoogleFonts.plusJakartaSans, Button 14r, Card 18r, Input 12r)
- Supabase Client: `lib/core/network/supabase_client.dart` -> `supabase`, `AppSupabase`
- Main Entry: `lib/main.dart` -> `SibasApp`
- Router: `lib/core/router/app_router.dart` -> `AppRouter`, `routerProvider`
- Transaction Status Helper & UI Label Mapper: `lib/core/utils/status_helper.dart` -> `TransactionStatusHelper.toDisplayLabel(status)` ('Menunggu Verifikasi', 'Disetujui', 'Ditolak', 'Kedaluwarsa')
- Admin Search & Filter Criteria: `lib/features/verification/domain/models/admin_metrics_model.dart` -> `AdminTransactionFilter(query, status, startDate, endDate)`
- Dynamic Balance & Metric Display: `lib/core/widgets/saldo_hero_card.dart` (kondisional jika tarif > 0 vs berat kg)

## Reusable UI Widgets (Design System Prototipe)
- Status Badge: `lib/core/widgets/status_badge.dart` -> `StatusBadge` (Menunggu #B45309, Disetujui #15803D, Ditolak #B91C1C)
- Hero Header: `lib/core/widgets/hero_header.dart` -> `HeroHeader` (LinearGradient hijau, SIBAS icon branding, sapaan user)
- Saldo Hero Card: `lib/core/widgets/saldo_hero_card.dart` -> `SaldoHeroCard` (transparan 14%, dynamic rate Rp/kg vs kg, CTA button)
- Transaction List Item: `lib/core/widgets/tx_list_item.dart` -> `TxListItem` (18r card, category icon with mint background, metrics, badge)

## Auth & Role Management (Task 2)
- UserModel: `lib/features/auth/domain/models/user_model.dart` -> `UserModel`
- Auth Repository: `lib/features/auth/data/auth_repository.dart` -> `AuthRepository`
- Auth Provider: `lib/features/auth/presentation/providers/auth_provider.dart` -> `authStateProvider`, `currentUserProvider`
- Login Screen: `lib/features/auth/presentation/screens/login_screen.dart` -> `LoginScreen`
- Register Screen: `lib/features/auth/presentation/screens/register_screen.dart` -> `RegisterScreen`

## Mahasiswa Dashboard & Deposit Features (Task 3)
- Transaction Model: `lib/features/history/domain/models/transaction_model.dart` -> `TransactionModel`
- Transaction Repository: `lib/features/history/data/transaction_repository.dart` -> `TransactionRepository`
- Transaction Providers: `lib/features/history/presentation/providers/transaction_provider.dart` -> `recentTransactionsProvider`, `allStudentTransactionsProvider`
- Mahasiswa Dashboard: `lib/features/dashboard/presentation/screens/dashboard_screen.dart` -> `DashboardScreen`
- Waste Category Model: `lib/features/deposit/domain/models/waste_category_model.dart` -> `WasteCategoryModel`
- Deposit Repository: `lib/features/deposit/data/deposit_repository.dart` -> `DepositRepository`
- Deposit Providers: `lib/features/deposit/presentation/providers/deposit_provider.dart` -> `wasteCategoriesProvider`, `transactionDetailProvider`
- Form Setor Sampah: `lib/features/deposit/presentation/screens/setor_screen.dart` -> `SetorScreen`
- QR Display Screen: `lib/features/deposit/presentation/screens/qr_display_screen.dart` -> `QrDisplayScreen`

## Admin Verification & Metrics Module (Task 4)
- Admin Metrics Model: `lib/features/verification/domain/models/admin_metrics_model.dart` -> `AdminMetricsModel`, `AdminTransactionFilter`
- Verification Repository: `lib/features/verification/data/verification_repository.dart` -> `VerificationRepository`
- Verification Providers: `lib/features/verification/presentation/providers/verification_provider.dart` -> `adminMetricsProvider`, `adminTransactionsProvider`, `adminFilterProvider`
- Verification Bottom Sheet: `lib/features/verification/presentation/widgets/verification_bottom_sheet.dart` -> `VerificationBottomSheet`
- Admin Dashboard Screen: `lib/features/verification/presentation/screens/admin_dashboard_screen.dart` -> `AdminDashboardScreen`
- Admin QR Scan Screen: `lib/features/verification/presentation/screens/admin_scan_screen.dart` -> `AdminScanScreen`
- GitHub Actions Workflow: `.github/workflows/build-apk.yml`

## History Screens & Web PWA (Task 5)
- Mahasiswa History Screen: `lib/features/history/presentation/screens/history_screen.dart` -> `HistoryScreen`
- Admin History Screen: `lib/features/history/presentation/screens/admin_history_screen.dart` -> `AdminHistoryScreen`
- PWA Manifest: `web/manifest.json` (theme_color: #0E7A4F, background_color: #F3F8F5)
- Web Entry HTML: `web/index.html` (SIBAS PWA title, meta tags, and loading indicator)
- Vercel SPA Config: `vercel.json` (rewrites to /index.html)