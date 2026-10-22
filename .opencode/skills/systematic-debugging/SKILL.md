---
name: systematic-debugging
description: Use when encountering any bug, test failure, CI failure, or unexpected behavior, before proposing fixes
---

# Systematic Debugging

## Overview

**Core principle:** ALWAYS find root cause before attempting fixes. Symptom fixes are failure.

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If you haven't completed Phase 1, you cannot propose fixes.

## SIBAS: CI is the only reproduction surface

No local Flutter SDK. You cannot run the failing code. Reproduction = the failing CI run:

```bash
gh run list --limit 10
gh run view <run-id> --log-failed      # failing step only
gh run view <run-id> --log             # full log, grep the file/line you touch
```

Read the actual analyzer error line before editing. `flutter analyze` errors name `file:line:col` and the rule — quote it in your reasoning. Never guess at a Dart error from memory: APIs in this repo (`withValues`, Riverpod 2.x `Notifier`, GoRouter 14) differ from older Flutter/plugin versions.

If the failure only appears in the `build-apk` step and not `analyze`, the cause is a compile/link/platform issue, not a lint issue. That distinction changes the fix.

## When to Use

Any technical issue: failing CI, build failures, runtime bugs, unexpected behavior, performance problems.

**Especially when:** under time pressure, "just one quick fix" seems obvious, previous fix didn't work, you don't fully understand the issue.

## The Four Phases

### Phase 1: Root Cause Investigation

1. **Read error messages carefully.** Full stack trace, line numbers, file paths, error codes. Do not skip warnings — in Dart, an analyzer warning near your change often explains the error.
2. **Reproduce consistently.** Which workflow, which step, which commit? Does the same commit fail twice?
3. **Check recent changes.** `git diff`, `git log -5 --stat`. New dependency? Renamed method? API deprecation?
4. **Gather evidence at component boundaries** when multiple layers are involved (widget → notifier → repository → RPC → RLS):

   ```
   For EACH boundary:
     - what data enters
     - what data exits
     - is auth/session present
     - what does the DB/RPC actually return
   ```

   Add temporary `debugPrint` at boundaries, push, read CI/or runtime logs, then analyze. Do not fix blind.
5. **Trace data flow.** Where does the bad value originate? Keep walking up the call chain until the source. Fix at the source.

### Phase 2: Pattern Analysis

1. Find working examples in this repo — same layer, same shape.
2. Read reference implementations completely (docs, schema, migration file).
3. List every difference between working and broken, however small.
4. Understand dependencies: Supabase schema, RLS policy, RPC signature in `supabase/migrations/`.

### Phase 3: Hypothesis and Testing

1. State one hypothesis: "X is the root cause because Y."
2. Test minimally — one variable, smallest change.
3. Verify: green CI run? Yes → Phase 4. No → new hypothesis, do not stack fixes.
4. When you don't know, say "I don't understand X" and gather more evidence.

### Phase 4: Implementation

1. Failing test first (see `test-driven-development`).
2. One fix, root cause only. No "while I'm here" refactors.
3. Verify with a fresh CI run (see `verification-before-completion`).
4. Fix didn't work? Count attempts. **3 or more → stop and question the architecture**, don't try fix #4.

## Red Flags — STOP and Follow Process

- "Quick fix for now, investigate later"
- "Just try changing X and see"
- "It's probably X, let me fix that"
- "I don't fully understand but this might work"
- Proposing fixes before reading the analyzer output
- "One more fix attempt" after 2+ failures

## Rationalizations

| Excuse | Reality |
|--------|---------|
| "Issue is simple" | Simple issues have root causes too |
| "No time for process" | Systematic is faster than guess-and-push loops at ~10 min per CI run |
| "I'll write test after" | Untested fixes don't stick |
| "Multiple fixes at once saves time" | You can't tell which one worked |
| "Test passes now" | Passing once ≠ regression-proof |

## Quick Reference

| Phase | Key Activities | Success Criteria |
|-------|---------------|------------------|
| 1. Root Cause | Read CI log, reproduce, check diff, trace | Understand WHAT and WHY |
| 2. Pattern | Find working examples, compare | Differences listed |
| 3. Hypothesis | One theory, minimal change | Confirmed or replaced |
| 4. Implementation | Test, fix, verify via CI | Green run, bug gone |
