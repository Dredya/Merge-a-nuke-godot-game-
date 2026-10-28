# QA Review — 100-Tier Expansion

**Date:** 2026-10-28  
**Build:** Phase 9 (100-tier expansion), on top of commit `baa2a95`  
**Test command:**

```bash
godot --headless --path . tools/test_phase9.tscn
```

---

## Verdict

**Automated result: PASS.** All functional checks in the new Phase 9 suite pass, along with the existing merge, raid, offline, low-quality and tutorial suites.

**Release caveat: one design blocker (P1).** The 100 tiers exist and render correctly, but the current free-spawn economy makes tiers above roughly 20 unreachable in normal play because only tier-1 bombs spawn and buying was removed. This is a balance/design decision that needs a product decision before release.

---

## Test Matrix

| Area | Result | Notes |
|---|---|---|
| 100-tier data | PASS | 100 sequential tiers; names, colors, income, build IDs valid |
| Milestones | PASS | 25 Hyper, 50 Apex, 75 Transcendent, 100 Singularity |
| Buying removal | PASS | No `buy_cost` data/property, no buy method, no Buy button |
| Bomb factory | PASS | All 100 build; labels match tier numbers |
| Triangle budget | PASS | Max 356 tris (tier 72); total 30,366 across all 100 |
| Resource sharing | PASS | Same-tier procedural bombs reuse mesh + material |
| Base UI | PASS | Merge hint present; cash HUD; no Buy Bomb button |
| Tutorial copy | PASS | Describes free spawns, no buying language |
| Free spawn | PASS | Places a tier 1 bomb; full-board state shows `FULL` |
| Screen glow | PASS | Tier 15 no glow; tier 100 glow; clears afterward |
| Milestone toasts | PASS | Hyper / Apex / Transcendent / Singularity |
| Shop | PASS | No bomb section, no buy buttons; Rewards + Missions remain |
| Save/load | PASS | Tier 100 and cash round-trip |
| Merge cap | PASS | 99 + 99 → 100; 100 + 100 remains 100 |
| Existing suites | PASS | `test_merge`, `test_raid`, `test_offline`, `test_low_quality`, `test_tutorial` |

---

## Findings

### P1 — BLOCKER (design): the 100-tier progression is not reachable
Bombs only spawn at **tier 1** (one every ~4 s default), and buying was removed. Making one tier `N` bomb requires `2^(N-1)` tier-1 bombs.

- **Tier 25 Hyper:** `2^24 = 16,777,216` spawns  
  ≈ **2.1 years** at the default 4 s interval; ≈ **0.8 years** at max spawn-speed upgrade.
- **Tier 50 Apex:** `2^49 ≈ 5.6×10^14` spawns ≈ tens of millions of years.
- **Tier 100 Singularity:** `2^99 ≈ 6.3×10^29` spawns ≈ **10^22 years**.

Cash and raids do not create bombs, so there is currently no path to high tiers.

**Recommended fix (choose one):**
1. **Spawn tier floor** — free spawns scale with the highest tier owned, e.g. spawn up to `max(1, highest_tier - 8)`. Keeps merging as the core loop.
2. **Free crate upgrade** — an upgrade line that periodically grants a bomb near your current highest tier.
3. **Prestige loop** — reset progress for a multiplier and higher starting spawns.
4. **Reintroduce a soft buying curve** — if buying returns, cap growth so early tiers remain affordable.

This should be decided before calling the 100-tier game “playable”.

### P2 — UX: “Shop” no longer sells anything
The Shop tab now contains Rewards, Redeem Code and Missions only. The nav label is misleading.

**Recommendation:** rename the tab to **Extras** or **Rewards**, or add non-purchase content (e.g. a bomb index / collection book).

### P3 — QA tooling: gallery samples 30 of 100
`scenes/bomb_gallery.tscn` shows all tiers 1–15 plus milestone samples through 100. That is useful for review, but not every tier is inspectable in one place.

**Recommendation:** add pagination or a “next page” debug control if full visual review of all 100 is needed.

### P4 — Maintainability: generator overwrites tiers 16–100
`tools/generate_tiers.gd` preserves tiers 1–15 from the current JSON and regenerates 16–100 from formulas. Manual edits to 16–100 will be lost if the generator is rerun.

**Recommendation:** documented (AGENTS) — use a separate seed/override file if manual high-tier tuning becomes necessary.

### P5 — Low: dead code
`GameState.set_slot()` is no longer used after removing shop purchases. Harmless, but can be removed.

### P6 — Low: large-number suffixes
High-tier income can display as `Oc` / `No` (octillion / nonillion). The formatter switches to scientific notation above `1e36`. Consider a small suffix legend or a settings toggle if players find the suffixes confusing.

### P7 — Save safety
`SaveManager` and `BaseScreen` now clamp saved slot values to `0..MAX_TIER`, so corrupt or future save values cannot create invalid tier indices.

---

## Visual QA

Reviewed captures:

- `capture_gallery100.png` — 30 representative tiers, color/ring progression, milestone legend
- `capture_step9_board.png` — board with tier 100, no Buy button, merge hint
- `capture_step9_singularity_merge.png` — Singularity merge, milestone toast, tier-100-only screen glow
- `capture_shop100.png` — Rewards/Missions-only Shop

Visual checks passed: tier-100 model is largest and brightest, milestone toast is readable, screen glow is subtle, gallery progression is clean, procedural tiers read as a continuous escalation.

---

## Performance

- 30,366 triangles across all 100 tier models.
- Worst tier: 356 triangles.
- Only 12 bombs exist on the board; on-screen triangle load stays roughly ≤4.5k even with high tiers.
- Meshes and materials are cached/reused per tier.
- Low quality still disables glow, particles and blob shadows.

---

## QA Sign-Off

Functional implementation is **approved**. The 100-tier feature is structurally sound and tested. The only release blocker is the **progression reachability** (P1), followed by the Shop naming UX (P2). Both are product decisions rather than code defects.
