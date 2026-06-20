---
name: zografee
description: Reference-driven generation of high-quality static design content — posters, editorial/magazine covers, social graphics, key visuals. Sources or accepts a reference image, measures it precisely, generates with Gemini Pro (via Nano Banana Pro), and converges to the user's taste via a logged decision ledger. Use when the user says /zografee or asks to create/design a poster, cover, graphic, or visual asset from (or in the style of) a reference.
argument-hint: [what to create + theme; attach a reference image if you have one]
---

# zografee — reference-driven static-content generation

(Greek *zographos*, "painter.") Turns a request + a reference into a high-quality static design, finalized at 4K. Reference-fidelity is the quality bar. Grounded across illustrated, editorial-light, dark-glow, duotone, gritty-halftone, and editorial-collage styles.

## Engine — separate repository (DEPENDENCY, not bundled)

**Clone once:**
```
git clone https://github.com/TopengDev/zografee.git {{ZOGRAFEE_DIR}}
pip install -r {{ZOGRAFEE_DIR}}/requirements.txt
```

All `python3 engine/*.py` commands below are run from `{{ZOGRAFEE_DIR}}/`.
Set `ZOGRAFEE_DIR` in `{{SECRETS_FILE}}` or `~/.pi/agent/secrets.env`.

**Engine modules:**
- `engine/gemini.py` — image gen/edit (flash + Pro), direct REST, retry-on-transient. Key from `{{SECRETS_FILE}}` (`GEMINI_API_KEY`).
- `engine/generate.py` — `ideate()` (flash, N cheap variants) · `finalize()` (Pro 4K) · `refine()` (image-edit). `FINALIZE_INSTRUCTION` is the canonical 4K-preserve prompt.
- `engine/analyze_ref.py` — measured palette, tonal field, grain, `typographic_scale()`, `tier_height()`.
- `engine/source_refs.py` — browser reference sourcing (Dribbble/Behance). **See FLAG below.**
- `engine/imageutil.py` — ImageMagick helpers (duotone, alpha-knockout, dither, upscale).
- `ledger/ledger.py` — `log_decision(...)` (the taste log).
- `lib/presets.py` — platform dimensions.
- `engine/render_satori.mjs` + `engine/fetch_fonts.py` — templating-only branch (see Routing).
Per job: `jobs/<slug>/{refs/, assets/, finals/, analysis.md, decisions.jsonl}`.

---

## PI COMPATIBILITY FLAGS

### FLAG 1 — Browser ref-route (needs config on Windows/pi)

`engine/source_refs.py` uses **qutebrowser** for Dribbble/Behance reference sourcing. qutebrowser is not available on Windows. Options:

- **Option A (recommended):** Skip auto-sourcing. Use user-supplied references only (`refs/ref.*`) — go straight to Step 2. This is the safest path on Windows and avoids the browser dependency entirely.
- **Option B:** Adapt `source_refs.py` to use **Playwright** (`playwright install chromium`) or the system's default Windows browser via the `agent-browser` skill. Requires installing Playwright: `pip install playwright && playwright install chromium`.
- **Status on pi: NEEDS CONFIG.** Auto-sourcing won't work out of the box. User-supplied refs work immediately.

### FLAG 2 — Shadow taste judge (needs a vision-capable model)

`judge/shadow.py` uses **Claude Sonnet vision** to predict the user's pick between design candidates. Pi runs **DeepSeek** by default, which may lack multimodal vision.

- **Option A:** Skip the shadow judge entirely. Comment out the `shadow.predict()` / `shadow.log_prediction()` calls in the flow. The user still picks at each gate — the judge is advisory only, never blocking.
- **Option B:** Swap `judge/shadow.py` to use a vision-capable model available on pi (e.g. Gemini Flash Vision via `GEMINI_API_KEY`, which you already need for generation).
- **Status on pi: OPTIONAL.** The core generation flow (Steps 0–5 minus shadow calls) works without it. The judge is a passive taste-tracker — skipping it loses the autonomy-roadmap feature but not the design output.

---

## North star

**Converge to the user's TASTE.** Their picks/edits/rejections = ground truth; log EVERY one to the ledger (the taste substrate). Engagement metrics, if ever used, are informational only.

## THE FLOW

**0 · Intake.** Medium, platform → dimensions (`lib/presets.py`), theme, copy intent, brand. Create the job dir; `ledger.log_decision(..., phase="brief", ...)`.

**1 · Reference** — one of:
- **User-supplied:** user attaches/links a reference → save to `refs/ref.*` → go to step 2.
- **Auto-source (needs browser, see FLAG 1):** `python3 engine/source_refs.py "<precise query>" jobs/<slug>/refs N` → **CURATION GATE** → present a 3–5 board → user PICKS.
- **CURATION GATE — relay a candidate ONLY if ALL hold:** (1) a single self-contained design of the target type — REJECT branding-collateral grids, UI/mockup collages, style guides, diagrams, multi-panel showcases; (2) aesthetically strong; (3) on-brief; (4) unambiguous (one dominant design). **Quality over filling slots. Vet at FULL SIZE — never relay raw thumbnails.** Precise query >> generic.
- Log the `reference_pick` + **why**.

**2 · MEASURED analysis** (the precision that makes it faithful). `python3 engine/analyze_ref.py refs/ref.*` then high-zoom crops (ImageMagick) then write `analysis.md` recording: **exact palette (hex)**, **typographic-scale spec** (each text block's % of canvas + tier ratios + left-margin alignment), composition, treatment (texture/duotone/dither/grain), mood, route, and the **copy mapping** (theme → every text slot, with engaging copy).

**3 · Ideate.** `generate.ideate(prompt, 'jobs/<slug>/assets', n=2-3, aspect=...)` on cheap flash. The prompt = the measured style (exact palette, composition, treatment, type genre) **+ the exact copy, stated explicitly**.

**4 · PICK gate.** Run the **shadow judge** if configured (see FLAG 2): `shadow.predict(candidates, facets, brief, ref_path)` → `shadow.log_prediction(...)`. THEN present variants side-by-side vs the reference. User picks (or requests edits → `refine()` or re-ideate). Log `final_pick` + **why** to the ledger, and `shadow.record_human_pick(job, phase, pick)` to score the judge. Do the same at the reference PICK gate.

**5 · Finalize + deliver.** `generate.finalize('assets/<chosen>.png', generate.FINALIZE_INSTRUCTION, 'finals/<slug>-4k.png', aspect=..., size='4K')` → Gemini Pro 4K (~3584px long edge, preserves design + exact copy). Verify the copy/colors survived; deliver in the right dimensions.

## ENGINE RULE = Gemini Pro

**`gemini-3-pro-image` is THE design engine.** Ideate on cheap `gemini-2.5-flash-image`; finalize on Pro 4K. Always prompt the EXACT copy + measured palette/style.

### Satori — NOT the creative path

`render_satori.mjs` is **demoted to programmatic templating only**: stamping the SAME fixed layout N× with swapped data/copy (price-card per product, personalized poster per user, exact brand-spec template). That's *data→layout at scale*. **Mental model: Gemini Pro = the designer · Satori = the print shop.**

## MEASURED-ANALYSIS DISCIPLINE (non-negotiable)

Vision perceives semantically + low-res; design is metric → **MEASURE, don't eyeball.**
- **Palette:** exact hex via `analyze_ref.py`. Catch warm-vs-cool whites, off-black vs pure black, subtle tints.
- **Proportion = BLOCK FOOTPRINT + space-fill + structure** — NOT a single per-line cap-height ratio. Measure each text *block's* % of canvas + the tier ratios; replicate structural tricks (e.g. wrapping a long hero word into more lines to dominate). Real scales are often *extreme* (dominant headline, fine-print body) — don't assume a moderate hierarchy.
- **Alignment is measured too:** every element's left-edge x (usually one shared margin); inline marker rows (line/number/label) vertically centered on one axis.
- **NEVER trust a measurement without viewing the trimmed crop** — `-threshold -trim` silently returns the crop-box height or catches 2 lines. Save the crop and read it back.
- **Compare sizes at NATIVE scale:** resize both images to one canvas and montage the crops **without resizing** — the only reliable size comparison.
- **Verify output vs reference** (sample bg/colors, native-scale side-by-side) before declaring done.

## QUALITY BAR = reference fidelity

The chosen reference — pre-vetted strong by the curation gate — **IS** the quality standard. Match it precisely (palette, proportion, composition, treatment); target **~90% fidelity**. `design-theory.md` (in this dir) is an analysis aid. **Do NOT inherit a blanket ban list** — a strong reference may legitimately use gradients / glow / glassmorphism / sparkles; fidelity, not avoidance, is the bar here.

## COPY = engaging, themed, mapped

For themed posters, write **engaging** copy mapped to the reference's text slots. Keep names/placeholders swappable across different themes.

## LEDGER (taste substrate — log everything)

`ledger.log_decision(job, content_type, phase, brief=, facets={content_type,brand,audience,platform,style_tags[]}, candidates=[{id,descriptor}], chosen=, rejected=[], why=, job_dir=)`. Phases: `brief · reference_pick · final_pick · edit · rejection`. **The `why` is the highest-value field — never skip it.** This is what the future autonomous judge converges against.

## SHADOW JUDGE (Step 4 — optional on pi, see FLAG 2)

`judge/` predicts the user's pick at each gate, behind the human decision — it never decides, it only guesses + gets scored.
- `judge/profile.json` — seeded taste profile (faceted principles grounded in the ledger *why*s). Dominant axis = **reference fidelity**; then cleaner composition, strong copy, restrained palette.
- `judge/shadow.py` — `predict(candidates, facets, brief, ref_path)` (requires vision model) → `{predicted, tie, confidence, ranking, why}`. `log_prediction()` before the gate, `record_human_pick()` after, `agreement_stats()` for the metric.
- `judge/backtest.py` — replays the judge on historical picks.
- **Pi setup:** skip shadow calls entirely (Option A from FLAG 2), OR swap to Gemini Flash Vision (Option B). The core generation flow works without the judge.

## AUTONOMY ROADMAP (earned, not switched)

Instrument (ledger) → seed taste profile (`judge/profile.json`) → shadow-mode judge (accumulating real agreement%) → graduated autonomy once measured agreement clears ~85% → scheduled "dream" consolidation regenerating the taste profile from accumulated shadow data. Until earned, the user picks the gates.

## SECRETS REQUIRED

In `{{SECRETS_FILE}}` (`~/.pi/agent/secrets.env`):
```
GEMINI_API_KEY=...        # required: image generation (flash + Pro)
ZOGRAFEE_DIR=...          # path to TopengDev/zografee clone
# Optional for shadow judge (FLAG 2 Option B):
# ANTHROPIC_API_KEY=...   # if using Claude vision for the judge
```

**NEVER embed API keys in skill files or commit them to this repo.** pi-setup is PUBLIC.
