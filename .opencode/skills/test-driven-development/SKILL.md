---
name: test-driven-development
description: Use when implementing any feature or bugfix, before writing implementation code
---

# Test-Driven Development (TDD)

## Overview

Write the test first. Watch it fail. Write minimal code to pass.

**Core principle:** If you didn't watch the test fail, you don't know if it tests the right thing.

## SIBAS: RED and GREEN happen in CI

No local Flutter SDK, so `flutter test` cannot be run on the dev machine. The red-green cycle runs through GitHub Actions:

```bash
# RED: push the test alone, watch it fail for the right reason
gh run watch <run-id> --exit-status
gh run view <run-id> --log-failed     # must show your assertion failing, not a compile error

# GREEN: push the implementation, watch it pass
gh run watch <run-id> --exit-status
```

A test that fails because of a typo, an import error, or a missing symbol is **not** a RED. It must fail on the assertion.

Cost per cycle is one CI run (~2 min on the `analyze` workflow, longer on build). Batch nothing: one test, one cycle.

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Wrote code before the test? Delete it. Start over. "Keep as reference" is testing-after in disguise.

## Red-Green-Refactor

### RED — write one failing test

- One behavior. If the name needs "and", split it.
- Real code, not mocks, unless the dependency is a network/DB boundary.
- Place it under `test/` mirroring `lib/` path.

### Verify RED — mandatory

Confirm the failure message is your assertion, not a compile error.

### GREEN — minimal code

Simplest implementation that passes. No options, no config, no "for later". Target the file the plan allows (max 1–2 files per execution).

### Verify GREEN — mandatory

Test passes, and the project's full test suite still passes. A green test of yours with a red suite elsewhere is not green.

### REFACTOR

Only after green. Remove duplication, improve names. No behavior changes.

## Good Tests

| Quality | Good | Bad |
|---|---|---|
| Minimal | One behavior | `test('validates email and domain and whitespace')` |
| Clear | Name states behavior | `test('test1')` |
| Honest | Asserts real behavior | Asserts a mock was called |

## Rationalizations

| Excuse | Reality |
|---|---|
| "Too simple to test" | Simple code breaks; the test costs a minute |
| "I'll test after" | Tests-after pass immediately, proving nothing |
| "Already manually tested" | No local runtime here — you cannot have |
| "TDD slows me down" | One CI round trip beats a broken `main` |
| "Need to explore first" | Explore, throw it away, then TDD |

## Red Flags — STOP

- Implementation before test
- Test passes on first run (you tested existing behavior)
- Can't explain why the test failed
- "Tests added later"
- Skipping full-suite check because "my file is green"

## Flutter notes

- Pure Dart logic (validators, formatters, models, balance math) → plain `test/`. Cheap, fast, high value.
- Widgets → `testWidgets` + `pumpWidget`; keep to one assertion of visible behavior.
- Supabase calls → test the mapping/parsing layer, not the network. Mock the client at the repository boundary only.
- Amount/balance calculations are money: always test rounding and zero/negative edges.
