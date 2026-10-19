# SIBAS Project Configuration (CLAUDE.md)

## Project Overview
SIBAS - Sistem Informasi Bank Sampah Poltekkes Kemenkes Yogyakarta.
Flutter application using Supabase as backend.

## Commands
- Run app: `flutter run`
- Build APK: `flutter build apk` (or via CI)
- Test: `flutter test`
- Lint: `flutter analyze`

## Architecture
- Pattern: Feature-based (Clean Architecture light).
- State Management: Flutter Riverpod.
- Routing: GoRouter.
- Data Layer: Supabase (PostgreSQL).

## Rules
- Always maintain Clean Architecture structure (`data`, `domain`, `presentation` folders).
- Use `flutter_riverpod` for state.
- Keep UI components reusable in `lib/core/widgets`.
- After completing any task, update `task.md` with progress.
