# AGENTS.md — Merge-a-Nuke

## Game Concept
Android idle merge-and-raid game (Godot 4.7, GDScript, Mobile renderer, 3D, Roblox-style).

- Merge bombs on a board into **100 tiers** of increasingly powerful bombs.
- The top tier (Singularity) generates **cash per second**, including while the game is closed.
- Bombs arrive from a free spawn timer; there is no bomb purchasing system.
- **Raid** AI bases to steal their cash.
- **Lock** your base with a **timed shield** to protect it from raids.
- **Redeem codes** for rewards.
- **Daily rewards** for returning players.

## Folder Structure
- `scenes/` — Godot scenes (`.tscn`).
- `scripts/` — GDScript source (`.gd`).
- `resources/` — Godot `Resource` files (`.tres`) for game data and the shared UI theme.
- `data/` — JSON data files (tiers, upgrades, codes, missions, balance).
- `assets/` — Original art and audio only. Fonts are open-license (SIL OFL) files in `assets/fonts/`.
- `addons/` — Editor plugins.

## Coding Rules (all future work)
1. Use **static typing** in GDScript; comment non-obvious logic.
2. Keep game data (tiers, upgrades, codes, missions, balance) in **Resources or JSON**, never hardcoded in scripts.
3. Build 3D art from Godot primitives and code only. Do not import external 3D art/textures.
4. After every change run `godot --headless --path . --quit` and fix **all** errors before continuing.
5. Commit after each phase with a descriptive message.

---

## 3D Visual Design Spec (authoritative)

### 1. World and camera
- Fixed `Camera3D`, isometric-style: yaw 45°, pitch −35°, orthographic.
- Player plot: **4×3 grid of slots** on a blocky baseplate slab.
  - Slab top `#4CAF50`, left side `#2E7D32`, right side `#3E9B43`.
  - Each slot is a flat diamond-aligned pad (thin BoxMesh) `#66C26A`, small gap between pads.
- Environment: `ProceduralSkyMaterial` sky gradient `#5BB8FF` (top) → `#BFE6FF` (horizon);
  green ground `#9BE08A`; a few floating white blocky clouds (BoxMesh) drifting slowly.
- One directional light, no real-time shadows.
- `WorldEnvironment` with low-intensity glow so emissive parts glow.
- Every bomb has a cheap blob shadow (flat dark transparent disc).

### 2. Bomb tiers
Each bomb is built in code from primitives (`SphereMesh`, `CylinderMesh`, `CapsuleMesh`,
`BoxMesh`, `PrismMesh`, `TorusMesh`) with `StandardMaterial3D`. Glowing parts use emission.
Each bomb has a billboard `Label3D` showing the doubled value `2^(tier-1)` (white, dark outline), not the tier index. All bombs gently bob
and glow-pulse (looping Tweens). Budget: ≤ ~300 triangles per bomb.

**Tiers 1–15 (hand-tuned showcase):**
1. **Classic** — dark round body `#151A30`→`#5A6694`, gray cap, curved fuse, sparking yellow tip `#FFC83D` (CPUParticles3D).
2. **Steel** — silver-blue sphere `#F2F6FF`→`#6C7BA8`, metal band (Torus), two side fins, dark cap.
3. **Tech** — teal sphere `#3CD8C8`→`#0E3A4A`, emissive lime ring `#B6F23C`, antenna with glowing tip.
4. **Gold Missile** — upright gold capsule `#FFE58A`→`#A86A10`, cone nose, two fins, orange stripe `#FF9A3D`, gloss highlight.
5. **Plasma Core** — dark sphere `#14070F`, crossed orbiting orange/gold rings, glowing core `#FFF3B0`→`#FF6A3D`.
6. **Neon Warhead** — pink/purple rocket (`#FF7A9A`, `#C03A9A`, `#5A1FA0`), emissive cyan stripes, glowing cockpit, purple fins, cyan glow disc, two orbiting cyan lights.
7. **Ion** — chrome sphere inside a floating cage of three thin glowing rings.
8. **Crystal** — faceted blue crystal (prism meshes), bright core, floating shards.
9. **Antimatter** — split black/white halves, energy seam, swirling particles.
10. **Solar Flare** — golden sphere, animated fire corona, short flame particles.
11. **Void** — black sphere, purple event-horizon ring, inward-swirling particles.
12. **Quantum Nuke** — transparent shell, rotating inner geometric core, color-shifting emission.
13. **Star Core** — bright star, four rotating light beams, orbiting mini planets.
14. **Galaxy** — dark sphere with spiral galaxy swirl, drifting star particles.
15. **Omega Nuke** — rainbow-shifting core, crown of floating rings, trailing sparkles.

**Tiers 16–99 (procedural escalation):**
- One procedural builder scales with tier: body radius `0.45 → 0.70`, 2–4 rotating rings,
  growing emissive core, two fins, and orbiting shards from tier 50 upward.
- Body/glow colors progress cyan → blue → indigo → purple → magenta via HSV.
- Tier names for procedural tiers (16–99) are the formatted income value (e.g. `32.8K`, `4.19M`)
  via the same K/M/B/… suffix rules as `Economy.format_number`; milestones keep
  **25 Hyper**, **50 Apex**, **75 Transcendent**, **100 Singularity**. Tiers 1–15 keep showcase names.
- Reaching a milestone shows a temporary gold `MILESTONE` toast on the base.
- Still ≤ ~300 triangles per bomb.

**Tier 100 — Singularity:**
- Biggest and brightest: rainbow-shifting core, three crown rings, four orbiting shards,
  trailing sparkles, scale 1.3×, and a subtle rainbow **screen glow when merged**.
- Only tier 100 triggers the screen glow; tier 15 does not.

All tier data (name, colors, income/sec, build id) lives in `data/nuke_tiers.json`
and the `NukeTier` resource. `tools/generate_tiers.gd` rebuilds the full 100-tier file.
Bomb purchasing is removed; `buy_cost` is no longer part of the tier data.

### 3. Merge and gameplay feel
- 3D drag and drop: raycast from camera, lift bomb, follow the ground plane under the finger, snap to nearest slot.
- Same tier merges into next tier; different tier swaps; empty slot moves.
- Merge effect: bombs fly together, white flash, scale-pop, ring shockwave, particles in new tier color,
  sound hook, and `Input.vibrate_handheld(30)` (settings toggle).
- Pooled floating `+$` labels rise from bombs on each income tick.

### 4. Screen 1 — Base
2D Control UI over the 3D scene, safe-area aware.
- Top HUD: `CASH` (`#A9B6E0` small), gold amount `#FFC83D` (32px chunky),
  income `+$8.4K / sec` `#B6F23C`; right blue-outlined lock box (`#3A7BFF` border on `#0B1020`)
  with countdown and `BASE LOCKED`.
- Under plot: `Next free bomb` panel + progress bar (`#B6F23C` on `#0B1020`) + seconds left.
- Below it a muted merge hint: `MERGE TWO IDENTICAL BOMBS TO LEVEL UP`.
- Bombs arrive free on a timer; there is no Buy Bomb button or bomb shop.
- Bottom nav, 5 icon buttons: Base, Shop, Raid, Upgrades, Settings (active lime `#B6F23C`, inactive `#A9B6E0`, ≥48px tall).

### 5. Screen 2 — Raid
- Top 3D mini scene: player's neon warhead (tier 6) arcs through the sky on a dotted white path
  toward a small enemy base plot (2×2).
- Target cards: colored avatar block, name, `Loot: $310K` gold, orange `Launch` button `#FF6A3D`;
  locked targets show a gray `Locked` tag.
- Gold `Revenge` section with green `Revenge` buttons.
- Raid animation: missile launch, flame trail, parabolic arc, explosion with particles + camera shake,
  then stolen-cash popup.

### 6. Screen 3 — Offline earnings popup
- Dark dim overlay over the base. Centered panel: `Welcome back!`,
  `Your nukes worked for 5h 12m`, huge gold `+$2.4M`,
  green `Claim x2 (watch ad)` button, smaller blue-gray `Claim` button below.

### 7. UI style rules
- Roblox-like chunky look: panels `#141C38` at 90% opacity, 3px `#0B1020` outlines, 14px rounded corners.
- Buttons: flat bright colors (green `#3DDC5A`, orange `#FF6A3D`, blue-gray `#3A4673`),
  thick darker bottom border (6px) that shrinks on press.
- Fonts: chunky rounded display font (Lilita One) + clean bold sans (Nunito Sans), bundled open-license.
  Bright button text is white with dark drop shadow.
- One shared `Theme` resource (`resources/ui_theme.tres`).

### 8. Performance
- Target 60 FPS on low-end phones.
- Low-poly meshes, cached/reused meshes + materials per tier, CPUParticles3D, no real-time reflections,
  at most one cheap shadow.
- Settings graphics quality option: **Low** disables glow, particles, and blob shadows.

---

## Implementation Checklist (3D visual rebuild)
- [x] Spec added to AGENTS.md.
- [x] Step 1 — Environment, camera, baseplate, slots.
- [x] Step 2 — Tier 1–6 bomb builders + debug gallery scene for all 15 tiers.
- [x] Step 3 — Tier 7–15 bomb builders.
- [x] Step 4 — 3D drag and drop, merge effects, bobbing/glow.
- [x] Step 5 — Shared theme, HUD, nav bar.
- [x] Step 6 — Raid screen and 3D raid animation.
- [x] Step 7 — Offline earnings popup.
- [x] Step 8 — Performance pass, final validation.
- [x] Phase 9 — 100-tier expansion: generated data, procedural tiers 16–99, tier-100 Singularity, milestones, buying system removed.

## Implementation Notes
- `scenes/main.tscn` holds the safe-area shell and five-button nav. Each screen
  owns its own `SubViewport` with `own_world_3d` so 3D and Control UI compose cleanly.
- `scripts/low_poly.gd` caches primitive meshes/materials and caps tessellation for mobile.
- `scripts/bomb_factory.gd` builds all 100 tiers: bespoke 1–15, procedural 16–99, and the
  tier-100 Singularity. `scripts/bomb.gd` runs the bob, glow pulse, ring spinners,
  hue-shifting cores and vortex animation.
- `data/nuke_tiers.json` is generated by `tools/generate_tiers.gd`; edit the existing
  tiers or the generator, then rerun it to rebuild all 100 entries.
- Shop now contains daily reward, redeem codes and missions only. Bombs spawn free on the
  base timer; the Buy Bomb button and bomb purchases were removed.
- `resources/ui_theme.tres` is generated by `tools/build_theme.gd`; edit the builder and
  rerun it rather than hand-editing the serialized theme.
- Triangle budget is measured with `tools/count_tris.gd`; current total is 30,366 triangles
  across all 100 tiers, with the worst bomb at 356 triangles. Only 12 bombs are on the board.
- Graphics quality Low disables environment glow, bomb/merge/raid particles and blob shadows.
  Settings are persisted in `user://settings.cfg`, separately from game progress.
- Offline earnings require at least 60 seconds away and are capped by the offline-cap upgrade.

## Validation Commands
```bash
godot --headless --path . --quit
godot --headless --path . --quit-after 600
godot --headless --path . tools/test_merge.tscn
godot --headless --path . tools/test_raid.tscn
godot --headless --path . tools/test_offline.tscn
godot --headless --path . tools/test_low_quality.tscn
godot --headless --path . tools/test_tutorial.tscn
godot --headless --path . tools/test_phase9.tscn
godot --headless --path . --script tools/count_tris.gd
godot --headless --path . --script tools/build_theme.gd
godot --headless --path . --script tools/generate_tiers.gd
```
Debug/visual scenes: `scenes/bomb_gallery.tscn` (1–15 plus milestone samples through 100) and
`godot --path . --resolution 540x960 --script tools/capture.gd -- res://scenes/main.tscn user://shot.png base`
(capture also accepts `shop`, `raid`, `upgrades`, `settings` as the third user argument).

## Notes
- Original names, art, and audio only. Fonts are SIL OFL licensed (license texts included in `assets/fonts/`).
- The 100-tier pass removes bomb purchasing; only free spawns, merging, raids and upgrades remain.
- Current QA findings (including the unreachable high-tier progression risk) live in `QA_REVIEW.md`.
- Android export and real-device testing remain.
