---
name: oneshot-webapp
description: Build and deploy pitch-grade demo webapps fast. For recruiter demos, pitch presentations, or one-shot showcase projects that need to look amazing but ship in hours, not days.
---

# Oneshot Webapp

Build and deploy a pitch-grade demo webapp. Designed for speed + polish, not production robustness.

## NON-NEGOTIABLE RULES

1. **Pitch-grade design is priority #1** — never cut design polish to save time; cut SCOPE instead. Generic shadcn-default = failure.
2. **SAFE `/frontend-design` preset ONLY** — Japanese Minimal / Warm Craft / Editorial Luxury / Soft Structuralism. HIGH-VARIANCE (Neo-Brutalist, Magazine Editorial, Dark Cinematic, art-deco, maximalist, VARIANCE≥7) is BANNED unless explicitly overridden.
3. **Light mode ONLY** — no dark mode, no `next-themes`, no theme switcher.
4. **Ship fast** — cap thinking, act in visible steps, iterate the running app. No long architecture-planning blocks.
5. **Server-side secrets only + mandatory deterministic LLM fallback** — key in container `.env` (chmod 600), never `NEXT_PUBLIC_`/never in the image; the live demo must survive an API failure.
6. **Deploy to `https://<slug>.topengdev.com`** — per-subdomain Cloudflare A record (no wildcard), HTTPS via certbot behind nginx.

## Architecture

- **Next.js App Router** (TypeScript)
- **Tailwind CSS** for styling
- **Static export where possible** (`output: "standalone"` for SSR)
- **Server Actions** for API calls (no separate API server)
- Single page or multi-page with no DB (or lightweight SQLite if needed)

## Design Presets (SAFE ONLY)

### Japanese Minimal
- Background: #FAF8F5 rice paper
- Typography: Cormorant Garamond display + Inter Tight body
- Color: Charcoal #2B2B2B + indigo #3D4F7C accent
- Ultra-restrained — if it feels designed, remove more

### Warm Craft
- Background: #F4EDE4 linen
- Typography: Fraunces display + Nunito Sans body
- Color: Terracotta #C4704D + forest #3D5A3E
- Hand-crafted feel, organic blob shapes, visible texture

### Editorial Luxury
- Background: #FAF7F2 warm cream
- Typography: Playfair Display + DM Sans
- Color: Ochre, burgundy accents
- Magazine-style layouts, oversized type, dramatic whitespace

### Soft Structuralism
- Background: Silver-grey or warm white
- Typography: Instrument Sans + Plus Jakarta Sans
- Color: Desaturated with one punchy accent
- Large radius cards, diffused shadows, rounded everything

## GATES

### PRE-FLIGHT (before starting build)
- [ ] Safe design preset chosen (confirmed with user)
- [ ] No dark mode requested
- [ ] Scope is tight (one page or minimal multi-page)
- [ ] Slug derived for deployment
- [ ] Design direction committed (no "let's see how it looks" ambiguity)

### PRE-DEPLOY (before deploying)
- [ ] Clean build (`npm run build` passes)
- [ ] No `next-themes` installed
- [ ] No `dark:` variants in code
- [ ] `output: "standalone"` in next.config
- [ ] All secrets in `.env` only (server-side)
- [ ] LLM fallback implemented (demo survives API failure)
- [ ] A record created in Cloudflare

## Workflow

1. **Design intent** — 2 min max. Choose preset, confirm scope.
2. **Scaffold** — `npx create-next-app`, install only essentials.
3. **Core layout** — Hero, features, CTA. Ship to screen within 15 min.
4. **Polish** — Iterate on the running app. Fix visual issues live.
5. **LLM integration** — Add streaming demo with fallback.
6. **Deploy** — Cloudflare DNS, VPS via ssh, nginx, certbot.

## Rules

- Never add auth, databases, or complex state management
- Never add multi-language support (single locale only)
- Never add analytics, monitoring, or logging infrastructure
- Keep dependencies minimal (next, react, tailwind, maybe framer-motion)
- All copy must be real (no lorem ipsum)
