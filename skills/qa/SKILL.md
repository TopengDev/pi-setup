---
name: qa
description: Adversarial QA — hammers any codebase across testing dimensions and produces a severity-graded markdown report. Supports quick mode (functional + edge cases + UX) and full mode (all 10 dimensions).
---

# /qa Skill — Adversarial QA

Real QA asks "how can this break?" not "does this pass?"

## Usage

```
/qa quick   — smoke test: functional + edge cases + UX spot-check
/qa full    — deep adversarial: all 10 dimensions
```

## Execution Rules

1. **Report only — never auto-fix.** Findings go into `./QA.md`. Remediation is the developer's decision.
2. **Always clean up.** Remove any temp files created.
3. **Report path**: `./QA.md` — fixed path, overwritten each run.

## Phase 1: Detect & Discover

### Step 1: Detect Project Type

Scan for config files. First match wins:

| File | Type | Test Command | Build Command |
|------|------|-------------|---------------|
| `Cargo.toml` | Rust | `cargo test` | `cargo build` |
| `package.json` | TypeScript/JS | `npm test` or `npx vitest` | `npm run build` |
| `pyproject.toml` | Python | `python -m pytest` | `python -m build` |
| `go.mod` | Go | `go test ./...` | `go build ./...` |
| `Makefile` | Universal | `make test` or `make check` | `make` or `make build` |

### Step 2: Extract Test Commands

From the detected config, extract: test command, build command, lint command, test file patterns.

### Step 3: Discover Test Infrastructure

```bash
find . -name '*_test.go' -o -name '*_test.rs' -o -name '*.test.ts' -o -name '*.test.js' \
       -o -name '*.spec.ts' -o -name '*.spec.js' -o -name 'test_*.py' -o -name '*_test.py' 2>/dev/null | head -50
```

## Phase 2: Execute Tests (Mode-Dependent)

### Quick Mode (`/qa quick`)

3 dimensions:

**Dimension 1: Functional Testing** — Run existing test suite. Identify critical user flows by reading project structure. Verify error handling paths exist.

**Dimension 2: Edge Case Testing** — Test empty inputs, max length, unicode/emoji, special characters (SQL injection strings, shell metacharacters), boundary values, null/missing fields.

**Dimension 3: UX Spot-Check** — Review error messages (actionable vs cryptic). Identify operations without progress indicators. Walk through user journeys for dead ends.

### Full Mode (`/qa full`)

All 10 dimensions:

1. **Functional (Extended)** — Map all user flows, build adversarial tests, verify error handling paths, check integration points
2. **Edge Cases (Extended)** — Concurrent actions, encoding edge cases, numeric edge cases, time-related edge cases
3. **Cross-Platform Testing** — Terminal rendering, OS-specific paths, screen size assumptions
4. **Regression Testing** — Review recent git changes, identify risk areas, check for breaking changes
5. **Destructive Testing (Simulated)** — Map critical failure points, plan safe test procedures, rate by likelihood × impact
6. **UX Audit** — Error message review, feedback gaps, flow analysis, consistency check, accessibility
7. **Performance Testing** — N+1 queries, unbounded operations, memory leak indicators, large dataset handling
8. **Security Testing** — SQL injection, XSS, command injection, auth bypass, data leaks, hardcoded secrets
9. **State Testing** — Fresh install, missing files, corrupt config, migration, state recovery
10. **Visual Testing** — UI code review, responsive design, terminal output formatting

## Phase 3: Generate Report

### Severity Grading

| Severity | Label | Criteria |
|----------|-------|----------|
| **P0** | Critical | System crash, data loss, security vulnerability, core feature broken |
| **P1** | High | Feature broken for specific inputs, significant UX failure, blocks usage |
| **P2** | Medium | Edge case failure, confusing UX, minor security concern |
| **P3** | Low | Cosmetic issue, minor inconsistency, nice-to-have improvement |
| **P4** | Cosmetic | Spelling, formatting, color, alignment — no functional impact |

### Verdict

- **SHIP**: No P0 or P1 findings
- **FIX BEFORE SHIP**: Has P0 or P1 findings that are fixable
- **DO NOT SHIP**: Has P0 findings indicating fundamental brokenness

Write the report to `./QA.md` with executive summary, dimension results table, findings by severity, and recommendations.
