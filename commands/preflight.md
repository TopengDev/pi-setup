# /preflight — Local CI/CD Checks

Run local CI/CD checks before pushing to avoid failed workflows.

## Workflow

### 1. Discover CI/CD workflows

Read all workflow files:
- `.github/workflows/*.yml` / `.github/workflows/*.yaml`
- `Dockerfile` and `docker-compose.yml` if present

Parse each workflow to extract the actual jobs and steps — linting, type checking, testing, building.

### 2. Run checks locally

Execute the equivalent local commands for each CI step found:

**Linting & Formatting**
- Go: `golangci-lint run ./...` or `go vet ./...`
- TypeScript/JavaScript: `npx eslint .` or the lint script in package.json
- Python: `ruff check .` or `flake8`

**Type Checking**
- TypeScript: `npx tsc --noEmit`

**Tests**
- Go: `go test ./...`
- Node: `npm test` or `npx vitest run` or `npx jest`
- Python: `pytest`

**Build**
- Node: `npm run build` or `npx next build`
- Go: `go build ./...`
- Docker: `docker compose build` (only if the CI workflow builds Docker images)

### 3. Report results

Present a clear summary table:

```
Preflight Results
-----------------
Lint:       PASS / FAIL
Types:      PASS / FAIL / N/A
Tests:      PASS / FAIL
Build:      PASS / FAIL
-----------------
Ready to push: YES / NO
```

### 4. Auto-fix loop

If ANY check fails:
1. Show the error output (truncated to key lines)
2. **Root cause analysis first** — read the relevant source code, understand WHY the error exists
3. Fix the root cause immediately
4. After fixing, re-run ALL checks from the beginning
5. If checks fail again, fix again and re-run ALL checks again
6. Keep looping until ALL checks pass
7. If stuck on same error after 3 attempts, stop and ask for help

### 5. Rules

- NEVER push code automatically — only report readiness
- If ALL checks pass on first run, tell the user it's safe to push
- If fixes were needed, commit them via `/commit` first
- Run checks in the same order CI would run them
