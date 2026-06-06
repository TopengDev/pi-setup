---
name: handover
description: Generate a comprehensive project handover documentation package for client delivery. Analyzes the actual codebase to produce accurate architecture docs, API docs, deployment guide, credentials map, maintenance guide, user guide, and BAST document. Use when the user needs to hand over a project or says /handover.
---

# Project Handover Documentation Generator

Generate a complete handover documentation package by analyzing the actual codebase. Every document must reflect real project state — no generic placeholders.

## 0. Setup

```bash
mkdir -p docs/handover
```

Infer project name from `package.json`, `go.mod`, `pyproject.toml`, `Cargo.toml`, `README.md`, or directory name.

## 1. Codebase Analysis (Do this FIRST)

Before writing any document, perform thorough analysis:

### 1a. Project Identity & Stack
Read: `package.json`, `go.mod`, `pyproject.toml`, `Cargo.toml`, `README.md`, `docker-compose.yml`, `Dockerfile`, `.github/workflows/*.yml`, `Makefile`

Extract: project name, description, languages/frameworks, dependencies, scripts/commands

### 1b. Architecture & Code Structure
```bash
find . -type f -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/vendor/*' | head -500
```

Identify: monorepo or single project, source code dirs, frontend/backend boundaries, DB ORM/migration files

### 1c. API Routes
Search for route definitions based on framework: Express/Fastify (`router.get`), Next.js App Router (`route.ts`), Django (`urlpatterns`), FastAPI (`@app.get`), Go (`HandleFunc`), Laravel (`Route::get`)

### 1d. Database Schema
Search for: Prisma (`schema.prisma`), Drizzle (`pgTable`), TypeORM (`@Entity`), Django (`models.py`), SQLAlchemy (`Column`), migration files

### 1e. Environment Variables
Read: `.env.example`, `.env.sample`, `.env.template`, Docker env sections
Search codebase for: `process.env.`, `os.environ`, `os.Getenv`

### 1f. Infrastructure & Deployment
Read: `Dockerfile`, `docker-compose.yml`, CI workflow files, `terraform/`, `k8s/`, platform configs

### 1g. Third-Party Integrations
Search for SDK imports: stripe, twilio, sendgrid, aws-sdk, firebase, supabase, clerk, sentry, etc.

## 2. Generate Documents (8 files)

Generate all documents in `docs/handover/`:

1. **handover.md** — Handover Summary: project overview, deliverables checklist, team, warranty terms
2. **architecture.md** — Architecture Documentation: Mermaid diagrams, component breakdown, data flows, DB schema, API architecture, third-party integrations
3. **api.md** — API Documentation: every endpoint with method, path, middleware, request/response types, error codes
4. **deployment.md** — Deployment Guide: prerequisites, env vars (never actual secrets), local setup, Docker, CI/CD, rollback procedures
5. **user-guide.md** — User Guide: feature walkthrough, admin panel docs, FAQ
6. **credentials.md** — Credentials Map: WHERE credentials are stored (never the secrets themselves), service accounts, server access
7. **maintenance.md** — Maintenance Guide: monitoring, troubleshooting, scaling, backup & recovery
8. **bast.md** — Berita Acara Serah Terima (bilingual ID/EN formal handover certificate)

## 3. Final Output

Create `docs/handover/README.md` as index, then report summary.

## Rules

1. **Accuracy over completeness**: Only document what exists. Leave sections empty rather than fabricate.
2. **No secrets**: NEVER include actual API keys, passwords, tokens. Only reference WHERE they are stored.
3. **Read before writing**: Always read source files before documenting them.
4. **Use Mermaid**: Prefer Mermaid diagrams for architecture, data flow, and ER diagrams.
5. **Bilingual BAST**: The BAST must be bilingual (Indonesian/English).
6. **Never fabricate**: Don't make up endpoints, tables, or features that don't exist.
