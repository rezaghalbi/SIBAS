# Code Contract & Utility Registry

## Database RPC Functions
- `approve_transaction(p_transaction_id UUID, p_admin_id UUID)`
- `reject_transaction(p_transaction_id UUID, p_admin_id UUID, p_reason TEXT)`

## Flutter Shared Components & Utilities
- Color System: `lib/core/constants/colors.dart` -> `AppColors`
- Theme System: `lib/core/constants/theme.dart` -> `AppTheme`
- Supabase Client: `lib/core/network/supabase_client.dart` -> `supabase`
- Transaction Status Helper & UI Label Mapper: `lib/core/utils/status_helper.dart` -> `TransactionStatusHelper.toDisplayLabel(status)` ('Menunggu Verifikasi', 'Disetujui', 'Ditolak', 'Kedaluwarsa')
- Admin Search & Filter Criteria: `lib/features/admin/domain/models/admin_filter.dart` -> `AdminTransactionFilter(query, status, startDate, endDate)`
- QR Scanner & Image Fallback Decoder: `lib/features/admin/presentation/widgets/qr_scanner_view.dart` & `lib/core/utils/qr_image_decoder.dart`
- Dynamic Balance & Metric Display: `lib/core/utils/currency_formatter.dart` / `lib/features/dashboard/presentation/widgets/balance_metric_card.dart` (kondisional jika tarif > 0 vs berat kg)