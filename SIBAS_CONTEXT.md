# SIBAS Technical Context (SIBAS_CONTEXT.md)

## Tech Stack
- **Language**: Dart
- **Framework**: Flutter
- **State Management**: Flutter Riverpod
- **Routing**: GoRouter
- **Backend**: Supabase
- **UI/Fonts**: Google Fonts, Material Design

## Directory Structure
- `lib/core`: Shared constants, widgets, network/router.
- `lib/features`: Feature-based architecture (auth, history, deposit, verification, dashboard).
- `assets`: Image assets.
- `web`: PWA files.

## Database Entities (Supabase)
- Based on `lib/features/.../domain/models/` files.
- `TransactionModel`
- `UserModel`
- `WasteCategoryModel`
- `AdminMetricsModel`

## API/RPC
- `approve_transaction(p_transaction_id, p_admin_id)`
- `reject_transaction(p_transaction_id, p_admin_id, p_reason)`

## Configuration
- `.claude/mcp.json` initialized for Git.
