---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires fresh verification evidence (CI run, not local) and confirming output before making any success claims; evidence before assertions always
---

# Verification Before Completion

## SIBAS constraint: no local Flutter SDK

This project is verified **only** in GitHub Actions. There is no `flutter` binary on the development machine. `flutter analyze` / `flutter test` cannot be run locally, so "it compiles on my machine" is never available as evidence.

The only acceptable evidence is a CI run:

```bash
gh run list --branch <branch> --limit 5          # find the run
gh run watch <run-id> --exit-status              # block until finished, non-zero on failure
gh run view <run-id> --log-failed                # read the failing step
```

Passing local checks are not evidence. A screenshot is not evidence. "Looks correct" is not evidence.

## Overview

**Core principle:** Evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT A FRESH GREEN CI RUN
```

If you have not seen a green `analyze` run for the current commit, you cannot claim the code compiles.

## The Gate Function

```
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: Which CI workflow proves this claim? (analyze, build-apk, deploy)
2. PUSH: Commit and push the exact tree you are claiming about
3. RUN: gh run watch <id> --exit-status, read the full log
4. VERIFY: Does the run confirm the claim?
   - If NO: quote the failing step and the error line
   - If YES: state the claim WITH the run id
5. ONLY THEN: Make the claim

Skip any step = lying, not verifying
```

## Common Failures

| Claim | Requires | Not Sufficient |
|-------|----------|----------------|
| Code compiles | `analyze` workflow green on this commit | Reading the code, "no obvious errors" |
| Tests pass | `flutter test` step green, 0 failures | No tests exist = not verified |
| Build succeeds | `build-apk` exit 0 | analyze green (analyze does not compile widgets) |
| Web deploy works | Vercel deployment `READY` + preview URL loads | CI green (deploy is a later step) |
| Bug fixed | Reproduction now passes in CI | Diff looks right |
| Agent completed | VCS diff shows the change | Agent reports "success" |
| Requirements met | Line-by-line checklist | Everything else green |

## Red Flags - STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before a green run ("Great!", "Done!")
- About to commit/push/PR without a run
- Trusting a subagent's success report without reading the diff
- "The change is trivial, CI not needed"
- **ANY wording implying success without a green run id**

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Should compile now" | Push and run analyze |
| "It's only a color change" | A typo in a color hex still fails analyze |
| "CI queue is long" | Waiting is cheaper than a broken main branch |
| "Agent said success" | Read the diff, then the run |
| "Partial check is enough" | Partial proves nothing |
| "Different words so rule doesn't apply" | Spirit over letter |

## Key Patterns

**Compile claim:**
```
✅ [push] [gh run watch → success] "analyze green, run 12345678"
❌ "Should compile now" / "No syntax errors visible"
```

**Agent delegation:**
```
✅ Agent reports success → git diff → push → CI green → report
❌ Trust agent report
```

**Requirements:**
```
✅ Re-read IMPLEMENTATION_PLAN.md → checklist → verify each item → report gaps
❌ "Phase done, all green"
```

## When To Apply

**ALWAYS before:**
- ANY variation of success/completion claims
- ANY expression of satisfaction about code state
- Committing, PR creation, task completion
- Moving to next task
- Closing a subagent's work
