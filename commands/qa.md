# /qa — Adversarial QA

Hammer any codebase across testing dimensions and produce a severity-graded markdown report.

## Usage

```
/qa quick   — smoke test: functional + edge cases + UX spot-check
/qa full    — deep adversarial: all 10 dimensions
```

## Execution Rules

1. **Report only — never auto-fix.** Findings go into `./QA.md`.
2. **Always clean up.** Remove any temp files created.
3. **Report path**: `./QA.md` — fixed path, overwritten each run.

## Dimensions

### Quick Mode (3 dimensions)
1. **Functional Testing** — Run existing test suite, identify critical user flows
2. **Edge Case Testing** — Empty inputs, max length, unicode/emoji, special characters, boundary values
3. **UX Spot-Check** — Error messages, progress indicators, user journey dead ends

### Full Mode (all 10 dimensions)
1. **Functional (Extended)** — Map all user flows, adversarial tests, integration points
2. **Edge Cases (Extended)** — Concurrent actions, encoding, numeric, time-related
3. **Cross-Platform** — Terminal rendering, OS-specific paths, screen sizes
4. **Regression** — Review recent git changes, breaking changes
5. **Destructive (Simulated)** — Critical failure points, likelihood × impact
6. **UX Audit** — Error messages, feedback gaps, flow analysis, accessibility
7. **Performance** — N+1 queries, unbounded operations, memory leaks, large datasets
8. **Security** — SQL injection, XSS, command injection, auth bypass, data leaks
9. **State Testing** — Fresh install, missing files, corrupt config, migration
10. **Visual Testing** — UI code review, responsive design, terminal formatting

## Severity Grading

| Severity | Label | Criteria |
|----------|-------|----------|
| **P0** | Critical | System crash, data loss, security vulnerability, core feature broken |
| **P1** | High | Feature broken for specific inputs, significant UX failure |
| **P2** | Medium | Edge case failure, confusing UX, minor security concern |
| **P3** | Low | Cosmetic issue, minor inconsistency |
| **P4** | Cosmetic | Spelling, formatting, color — no functional impact |

## Verdict

- **SHIP**: No P0 or P1 findings
- **FIX BEFORE SHIP**: Has P0 or P1 findings
- **DO NOT SHIP**: Has P0 findings indicating fundamental brokenness

## Full Documentation

See `skills/qa/SKILL.md` for complete dimension details and report format.
