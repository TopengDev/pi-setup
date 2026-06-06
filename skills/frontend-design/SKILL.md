---
name: frontend-design
description: Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when asked to build web components, pages, or applications. Generates creative, polished code that avoids generic AI aesthetics.
---

This skill guides creation of distinctive, production-grade frontend interfaces that avoid generic "AI slop" aesthetics.

## 1. i18n + Multi-Theme Mandatory Baseline

**Every website / web app / landing page / marketing site for the Aenoxa ecosystem MUST ship with i18n + multi-theme support out of the box. Non-negotiable from commit 0.**

### i18n requirements
- **next-intl** for Next.js projects. `[locale]` route segment + middleware.
- **Minimum locales**: `id` (Indonesian, DEFAULT) + `en` (English).
- **No hardcoded strings** in components. Every string in `messages/<locale>.json`.
- hreflang metadata on every page for SEO.

### Multi-theme requirements
- **next-themes** for Next.js projects.
- **Minimum themes**: `light` + `dark` + `system`.
- **Both themes polished** — not "light is main, dark is afterthought".
- **CSS variables for tokens** in `globals.css` (`--bg`, `--fg`, `--accent`, `--surface`, `--border`, etc).
- **Theme switcher visible** in nav. **Theme persists** via cookie, matches SSR (no FOUC).

### Exception
Internal-only admin tools MAY ship English-only single-theme.

## 2. INTERACTIVE SETUP

Before writing any code, run this setup with the user:

### Step 1: Mode Selection
| Mode | When to use |
|---|---|
| **New Build** | Starting from scratch |
| **Redesign** | Existing page needs visual overhaul |
| **Quick Polish** | Existing code needs refinement |
| **Surprise Me** | Pick everything yourself |

### Step 2: Vibe Selection
Present archetypes from §3 or let the user describe a custom vibe.

### Step 3: Intensity Dials (1-10)
| Dial | Description |
|------|-------------|
| **DESIGN_VARIANCE** | Layout diversity (symmetric → asymmetrical → expressive) |
| **MOTION_INTENSITY** | Animation amount (hover-only → transitions → cinematic) |
| **VISUAL_DENSITY** | Content density (sparse → balanced → data-dense) |

## 3. VIBE ARCHETYPES

### Ethereal Glass — SaaS, AI products, dev tools
- OLED black or deep navy background, mesh gradients, backdrop-blur cards
- Typography: Geist, Satoshi, Instrument Sans; monospace for code
- Single vivid accent (electric blue, mint, violet), everything else monochrome

### Editorial Luxury — Lifestyle, agencies, portfolios
- Warm cream (#FAF7F2) or parchment, CSS noise overlay at 2-4% opacity
- Serif display (Playfair Display, EB Garamond) + clean sans body (DM Sans)
- Muted earth palette — ochre, burgundy, forest. Max 1 accent

### Soft Structuralism — Consumer apps, health, fintech
- Silver-grey or warm white, subtle gradient washes
- Large radius cards (16-24px), diffused multi-layer shadows
- Massive grotesk display (Instrument Sans, Plus Jakarta Sans) at 16-18px body

### Neo-Brutalist — Indie brands, creative studios
- Concrete grey or raw white, visible grid lines
- Sharp borders (0px radius), exposed structure, no shadows
- Space Mono or JetBrains Mono primary. Black + white + ONE accent (red or blue)

### Japanese Minimal — High-end retail, luxury goods
- Warm off-white (#FAF8F5), hairline 0.5px borders, extreme padding (8rem+)
- Small body text (14px), generous letter-spacing. Cormorant Garamond or Noto Serif JP
- Charcoal + one muted accent (indigo or moss). Max 3 colors total

### Magazine Editorial — Media, publishing, fashion
- Pure white or ivory, full-bleed images as backgrounds
- Bold serif display (Playfair Display, Libre Bodoni) at extreme sizes (8rem+)
- Black + white + one editorial accent (burgundy or gold)

### Warm Craft — Artisan, F&B, handmade goods
- Warm linen (#F4EDE4) or kraft paper texture
- Fraunces or Vollkorn display + Nunito Sans body
- Earthy palette — terracotta, forest, cream, espresso

### Dark Cinematic — Entertainment, film, gaming
- OLED black #000000, film grain overlay (SVG noise 4-6%)
- Instrument Serif or Bodoni Moda display + Geist for UI
- Black + cool white + one accent (amber or crimson)

### Corporate Confident — Enterprise, B2B, fintech
- White #FFFFFF or light grey #F5F5F5
- Inter Tight or Geist for display and body. No serif.
- Navy + charcoal + white + one muted accent. NO warm colors.

### Playful Pop — Kids/education, consumer social, gaming
- Saturated pastel or bright solid blocks
- Sora or Plus Jakarta Sans at heavy weights. Karla for body.
- Maximum saturation — coral, electric purple, sunny, mint. 3-4 colors mixed.

### Gen Z Expressive — Youth brands, social-first
- Clashing neon blocks, zigzag section breaks (clip-path), thick borders
- Clash fonts intentionally — chunky sans + pixel fonts + monospace
- MAXIMUM expression — 5+ colors, dopamine palette. If it feels calm, it's wrong.

### Anti-Design / Experimental — Avant-garde studios
- Deliberately uncomfortable, interaction-gated content
- Custom cursor SVGs, elements that repel cursor, permanent "loading" states
- Either extreme monochrome or deliberately clashing neon-on-black

## 4. DESIGN ENGINEERING — Typography

### Font Selection Rules
- Display fonts: `letter-spacing: -0.02em` to `-0.04em`
- Body text: `max-width: 65ch` for readability
- Always set `-webkit-font-smoothing: antialiased` and `-moz-osx-font-smoothing: grayscale`
- Use `font-variant-numeric: tabular-nums` on numbers in tables/stats/counters
- Use `text-wrap: balance` on headlines
- Size scale: modular scale (1.2–1.333 ratio)
- Line height: display text 1.0–1.15, body text 1.5–1.7

### Font Pairings
- Playfair Display + DM Sans (editorial)
- Instrument Serif + Instrument Sans (modern)
- Fraunces + Outfit (warm tech)
- Space Mono + General Sans (dev/code)
- Cormorant Garamond + Nunito Sans (luxury)
- Bricolage Grotesque + Inter Tight (bold modern)

### Serif Constraint
Serif fonts are BANNED for Dashboard/Software UIs. Use sans-serif pairings.

## 5. DESIGN ENGINEERING — Surfaces & Layout

### Double-Bezel Card Architecture
Outer shell (1px padding, rounded) wrapping inner core creates depth without drop shadows.

### Optical Alignment
- Icon-only buttons: add 1-2px extra horizontal padding
- Icons next to text: 1px visual nudge for baseline alignment

### Image Outlines
`img { outline: 1px solid rgba(0,0,0,0.06); outline-offset: -1px; }`

### Layered Tinted Shadows
Replace borders with layered shadows using the element's own color, tinted.

### Button-in-Button Trailing Icon
For primary CTAs, embed a visual "inner button" for the trailing arrow/icon.

### Scale on Press
Apply `scale(0.96)` on `:active` for tactile feedback. Never below 0.95.

### Eyebrow Tags
Microscopic pill badges above headings: `rounded-full px-3 py-1 text-[10px] uppercase tracking-[0.2em] font-medium`

### Layout by Variance
- **1-3: Structured** — Centered hero, even-column grids
- **4-7: Offset** — Asymmetrical Bento, editorial splits, overlapping elements
- **8-10: Expressive** — Z-Axis cascade, masonry, diagonal section breaks

### Mandatory Interactive UI States
Every component: Loading (skeletal shimmer), Empty (beautiful composed state), Error (inline reporting), Tactile Feedback (`scale-[0.96]` on active).

## 6. MOTION

### Core Principles
- Only animate `transform` and `opacity` — never layout properties
- Never use `transition: all` — always specify exact properties
- Spring physics: `cubic-bezier(0.34, 1.56, 0.64, 1)` for overshoot
- Staggered reveals with `animation-delay` increment

### Motion by Intensity
- **1-3**: Hover scale(1.02) or translateY(-2px), focus ring, no page-load animation
- **4-7**: Staggered fade-up with blur clearing, IntersectionObserver scroll entry, color shifts
- **8-10**: Scroll-linked parallax, magnetic hover, morphing shapes, particle effects

### Reduced Motion
Always respect `prefers-reduced-motion: reduce`.

## 7. PERFORMANCE

- GPU-safe: only `transform` and `opacity`
- Backdrop-blur budget: only on fixed/sticky elements
- Grain overlay: SVG `<feTurbulence>` at 0.02-0.05 opacity
- All images: explicit `width`/`height` for CLS prevention
- Fonts: `font-display: swap`, preload critical fonts
- First-load JS < 200KB, LCP < 2.5s, CLS < 0.1

## 8. SCROLLYTELLING PATTERNS

### 6 Core Patterns
1. **Sticky Hero with Morphing Content** — Hero pins, content transforms on scroll (Apple product pages)
2. **Product Showcase / "Phone Frame" Scroll** — Device mockup stays centered, screenshots scrub through
3. **Sequential Reveal / Card Stack** — Cards stack and peel away one by one
4. **Horizontal Scroll Gallery** — Section pins, content scrolls horizontally
5. **Zoom-Out / "Google Maps" Reveal** — Start zoomed in on detail, pull back to show big picture
6. **Text Morph / Typewriter Scroll** — Text transforms character by character on scroll

### Scrollytelling Rules
- Must degrade gracefully on mobile (no pinning on viewport < 768px)
- Always provide a clear path to skip (scroll or click)
- Max total scroll distance for a single "jack": 400vh
- `IntersectionObserver` with `rootMargin`, never `window.addEventListener('scroll')`

## 9. RESPONSIVE DESIGN

- Mobile-first: design for 375px first, scale up
- Breakpoints: sm(640) md(768) lg(1024) xl(1280) 2xl(1536)
- Asymmetric layouts > md MUST collapse to single column below 768px
- Touch targets minimum 44×44px
- `min-h-[100dvh]` not `h-screen` (respects mobile browser chrome)
