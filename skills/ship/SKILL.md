---
name: ship
description: Full shipping pipeline — security review, test, version, commit, preflight, push. Use when the user says ship, deploy, push, or is done developing a feature.
---

## Ship Pipeline

One command to go from "done coding" to "pushed and CI-ready."

### Pipeline order

1. Security review — scan for vulnerabilities
2. Version & changelog — bump version, update CHANGELOG.md (if applicable)
3. README update — update docs if changes affect them (if applicable)
4. `/commit` — commit all changes
5. `/preflight` — run CI/CD checks locally
6. Push

### Step 1: Security Review

Run `git diff HEAD` to get all uncommitted changes, then analyze as a senior security engineer.

**Only flag issues with >80% confidence of real exploitability.**

**Check for:**
- Input Validation: SQL injection, command injection, XXE, path traversal, template injection
- Auth & Authorization: authentication bypass, privilege escalation, session flaws
- Crypto & Secrets: hardcoded API keys/passwords/tokens, weak crypto
- Injection & Code Execution: XSS, unsafe eval, prototype pollution, deserialization

**Do NOT report:**
- Denial of Service vulnerabilities
- Secrets stored on disk
- Rate limiting or resource exhaustion
- Pre-existing issues (only flag what's NEW in the diff)
- Theoretical issues with low practical impact

**If findings exist:** Present each with severity, file/line, description, and fix. Ask: "Which findings should I fix? (all / none / comma-separated numbers)". Fix selected findings.

**If no findings:** Print "Security review: clean" and proceed.

### Step 2: Version & Changelog (conditional)

**Detection:** Check for `CHANGELOG.md` in project root.

**If no CHANGELOG.md:** Skip this step entirely.

**If CHANGELOG.md exists:**
1. Read current version from `package.json`, `Cargo.toml`, or `pyproject.toml`
2. Suggest bump type based on changes: Bug fixes → `patch`, New features → `minor`, Breaking changes → `major`
3. Ask user: `Release: current v{version}. Bump? (patch / minor / major / skip)`
4. If user picks a bump, update version in the manifest and insert new CHANGELOG section (Keep a Changelog format)

### Step 3: README Update (conditional)

**If no README.md:** Skip. If README exists, review code changes for documented content impact. Update if needed, skip silently if no doc impact.

### Step 4: Commit

Invoke the `/commit` skill to commit all current changes.

### Step 5: Preflight CI/CD

Invoke the `/preflight` skill to run all CI/CD checks locally. Do NOT proceed until all checks pass.

### Step 6: Push

1. Determine branch: `git branch --show-current`
2. Push: `git push -u origin <branch>`
   - If behind remote: `git pull --rebase origin <branch>`, then push again

### Final Report

```
Ship Summary
============
Feature:      [what was shipped]
Branch:       [branch name]
Security:     CLEAN / {N} findings fixed
Preflight:    PASS
Version:      v{version} (if bumped) / unchanged
Commits:      [list of commit hashes and messages]
Pushed:       YES
============
```

### Rules

- Follow the pipeline order strictly — no skipping steps
- Each step must fully pass before moving to the next
- Never force push — if `git push` fails, stop and ask
- Security review is the ONLY mandatory interactive step
