# /frontend-design — Production-Grade UI

Create distinctive, production-grade frontend interfaces that avoid generic "AI slop" aesthetics.

## Interactive Setup

Before writing any code:
1. **Mode Selection** — New Build / Redesign / Quick Polish / Surprise Me
2. **Vibe Selection** — Pick from 12 archetypes or describe a custom vibe
3. **Intensity Dials** — DESIGN_VARIANCE, MOTION_INTENSITY, VISUAL_DENSITY (1-10)

## Vibe Archetypes

| Archetype | Best For | Key Traits |
|-----------|----------|------------|
| **Ethereal Glass** | SaaS, AI products, dev tools | OLED black, backdrop-blur, single vivid accent |
| **Editorial Luxury** | Lifestyle, agencies, portfolios | Warm cream, serif display, asymmetric grid |
| **Soft Structuralism** | Consumer apps, health, fintech | Silver-grey, large-radius cards, diffused shadows |
| **Neo-Brutalist** | Indie brands, creative studios | Concrete grey, sharp borders, monospace |
| **Japanese Minimal** | High-end retail, luxury goods | Warm off-white, hairline borders, extreme negative space |
| **Magazine Editorial** | Media, publishing, fashion | Full-bleed images, bold serif at extreme sizes |
| **Warm Craft** | Artisan, F&B, handmade | Warm linen, organic shapes, terracotta/forest |
| **Dark Cinematic** | Entertainment, film, gaming | OLED black, film grain, amber accent |
| **Corporate Confident** | Enterprise, B2B, fintech | Navy/charcoal, clean sans-serif, structured grid |
| **Playful Pop** | Kids/education, social, gaming | Saturated bright blocks, chunky shapes |
| **Gen Z Expressive** | Youth brands, social-first | Clashing neon, collage layout, maximalist |
| **Anti-Design** | Avant-garde studios | Zero-grid, deconstructed typography, experimental |

## Design Engineering

### Typography
- Display fonts: `letter-spacing: -0.02em` to `-0.04em`
- Body text: `max-width: 65ch`
- Size scale: modular scale (1.2–1.333 ratio)
- Line height: display 1.0–1.15, body 1.5–1.7
- Serif fonts BANNED for Dashboard/Software UIs

### Surfaces & Layout
- Double-bezel card architecture for depth
- Optical alignment nudges (1-2px)
- Layered tinted shadows instead of borders
- Scale on press: `scale(0.96)` on `:active`

### Motion
- Only animate `transform` and `opacity`
- Spring physics: `cubic-bezier(0.34, 1.56, 0.64, 1)`
- Always respect `prefers-reduced-motion: reduce`

### Performance
- GPU-safe: only `transform` and `opacity`
- Image `width`/`height` for CLS prevention
- Fonts: `font-display: swap`, preload critical
- First-load JS < 200KB, LCP < 2.5s

### Mandatory States
Every component: Loading (skeletal shimmer), Empty (beautiful composed), Error (inline reporting), Tactile Feedback.

## Full Documentation

See `skills/frontend-design/SKILL.md` for complete archetype specifications, font pairings, scrollytelling patterns, and responsive design rules.
