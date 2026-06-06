# /creative — Design Asset Generation

Generate high-quality design assets (social graphics, illustrations, logos, banners, icons, mockups) using AI image generation with multi-model routing.

**Reference:** See `skills/creative/design-theory.md` for the 35 design theories that inform every design decision.

## Quick Start

1. **Mode Selection** — New / Redesign / Quick Polish / Surprise Me
2. **Archetype Selection** — Pick from 12 vibe archetypes (Ethereal Glass, Editorial Luxury, Japanese Minimal, etc.) or describe a custom vibe
3. **Dial Confirmation** — Set DESIGN_VARIANCE, MOTION_INTENSITY, VISUAL_DENSITY (1-10 each)
4. **Brief Decomposition** — Extract asset type, dimensions, brand, mood, audience
5. **Design Concept** — Write a design brief before generating ANY image
6. **Model Selection** — Route to best model (Gemini, GPT Image, FLUX.2) based on asset type
7. **Generate + Self-Critique** — Generate 2 variations, score brutally against quality criteria
8. **Iterative Refinement** — Refine best variant up to 3 cycles
9. **Quality Gate + Delivery** — Final assessment, save outputs

## Available Models

| Model | Best For |
|-------|----------|
| **Gemini (Imagen)** | Social graphics, bold compositions, illustrations |
| **GPT Image 1.5** | Text-heavy banners, precise text rendering |
| **FLUX.2 Pro** | Photorealistic mockups, product photography |

## Output

All generated assets go to `/tmp/creative-output/`. Final deliverables copied to project directory on request.

## Full Documentation

See `skills/creative/SKILL.md` for the complete workflow, all 12 archetypes, hard bans, negative prompt mapping, and model-specific generation commands.
