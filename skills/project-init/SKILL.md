---
name: project-init
description: Scaffold a new client project with everything needed to start development immediately. Use when the user wants to create a new project, initialize a repo, start a new app, or says /project-init.
argument-hint: <project-name> <tech-stack (nextjs|go|python)>
---

Scaffold a complete, ready-to-develop project repository at `~/claude/Git/repositories/{project-name}/`.

Parse arguments into:
- **PROJECT_NAME**: kebab-case project name (first argument)
- **TECH_STACK**: one of `nextjs`, `go`, `python` (second argument)

If either argument is missing, stop and ask. Do not guess.

CRITICAL RULES:
- NEVER leave placeholder TODOs. Every file must be functional.
- NEVER overwrite an existing directory.
- NEVER commit secrets or .env files.
- All generated config must be valid and parseable.

## 1. Repository Setup

```bash
mkdir -p "$PROJECT_DIR" && cd "$PROJECT_DIR"
git init
git checkout -b main
```

Create `.gitignore` tailored to the tech stack.

## 2. Project Structure — Scaffold by Tech Stack

### For nextjs:
```bash
npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir --import-alias "@/*" --use-npm --yes
```

Additional dirs: `src/components src/lib src/hooks src/types src/styles tests/unit tests/integration tests/e2e docs scripts .github/workflows .github/ISSUE_TEMPLATE`

Install dev deps: `vitest @testing-library/react @testing-library/jest-dom @vitejs/plugin-react jsdom zod`

Create `vitest.config.ts`, `tests/setup.ts`, `src/lib/env.ts` (zod validation), `src/middleware.ts` (security headers), update `tsconfig.json` for strict mode, add scripts to `package.json`, set up husky + lint-staged.

### For go:
```bash
go mod init github.com/christopher/$PROJECT_NAME
```

Create: `cmd/$PROJECT_NAME/main.go`, `internal/config/config.go`, `internal/handler/health.go`, `internal/middleware/middleware.go`, `tests/unit/health_test.go`, `Makefile`, `.golangci.yml`

### For python:
```bash
python -m venv .venv && source .venv/bin/activate
pip install fastapi uvicorn pydantic pydantic-settings python-dotenv
pip install -D ruff mypy pytest pytest-cov pytest-asyncio httpx
```

Create: `src/main.py`, `src/core/config.py`, `src/api/health.py`, `src/middleware/security.py`, `tests/unit/test_health.py`, `pyproject.toml`, `Makefile`

## 3. CI/CD

Create `.github/workflows/ci.yml` with lint, type-check, test, build steps for the chosen stack.

Create `Dockerfile` and `docker-compose.yml` for development and `docker-compose.prod.yml` for production.

## 4. Documentation

Create: `README.md`, `docs/ARCHITECTURE.md`, `docs/API.md`, `docs/DEPLOYMENT.md`, `CONTRIBUTING.md`

## 5. AGENTS.md

Create `AGENTS.md` at project root with project overview, commands, architecture, code standards, environment setup, and deployment info.

## 6. Environment

Create `.env.example` with all required variables for the stack.

## 7. Create develop branch and initial commit

```bash
git add -A
git commit -m "chore: initial project scaffolding"
git checkout -b develop
```

## 8. Final Report

Output a summary showing project name, stack, location, branches, and next steps.
