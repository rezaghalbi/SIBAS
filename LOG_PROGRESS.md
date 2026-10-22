# LOG PROGRESS

## 2026-10-22 — Setup agent & CI (PR #1, branch `chore/agent-setup-ci`)

**Konfigurasi agent**
- `~/.config/opencode/oh-my-opencode-slim.json`: preset `9router` aktif, 6 agent pakai `9router/ds/deepseek-v4-flash`.
- Hapus `agent.explorer.model` (menunjuk `9router/9router-main-combo` yang tidak terdaftar).
- Hapus MCP `github` dari `opencode.json` project (header PAT placeholder, selalu gagal).

**Skills** (`.opencode/skills/`)
- `progress-logger` — diperbaiki: `skills.md` → `SKILL.md` (sebelumnya tidak ter-load).
- `ponytail` — lazy senior dev, MIT, dipasang ke oracle/designer/fixer.
- `sibas-glass-ui` — token glass + checklist + larangan `withOpacity`/widget duplikat.
- `systematic-debugging`, `test-driven-development`, `verification-before-completion` — versi yang disesuaikan: RED/GREEN dan verifikasi lewat CI, bukan lokal.

**CI**
- Baru: `.github/workflows/analyze.yml` (PR-only, `flutter analyze --no-fatal-infos` + test bila ada).
- `build-apk.yml`: Flutter dipin `3.47.7`; deploy produksi Vercel hanya dari `push` ke `main`, PR dapat preview.

**Aturan**
- `AGENTS.md`: `withOpacity` → `withValues`, satu `GlassPanel`, max 1–2 blur per layar, bagian 5 (verifikasi via CI), 6 (Supabase migration-only), 7 (keamanan).

**Kode**
- `verification_repository.dart`: perbaiki karakter rusak di awal file + lengkapi `getAllTransactions`, `getTransactionForVerification`, `approveTransaction`, `rejectTransaction`.
- `supabase/migrations/20261022000000_init.sql` ditambahkan ke repo.

**Hasil CI**
- `Analyze & Test` hijau (run 39726694566). Sisa 6 info lint di `main.dart` (`prefer_const_constructors`) dan 1 `anonKey` deprecated — tidak memblokir.
- Gate format dihapus: repo belum terformat dengan `dart format` 3.47 dan tidak ada formatter lokal.

**Ditunda**
- `GlassPanel` belum dibuat; `lib/` masih 0 `BackdropFilter`, jadi glassmorphism belum sesuai `AGENTS.md`.
