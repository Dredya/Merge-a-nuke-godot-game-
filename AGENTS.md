# AGENTS.md — Merge-a-Nuke

## Game Concept
Android idle merge-and-raid game (Godot 4.7, GDScript, Mobile renderer, 3D, Roblox-style).

- Merge bombs on a board into **15 tiers** of increasingly powerful bombs.
- The top tier (Omega nuke) generates **cash per second**, including while the game is closed.
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
Each bomb has a billboard `Label3D` tier number (white, dark outline). All bombs gently bob
and glow-pulse (looping Tweens). Budget: ≤ ~300 triangles per bomb.

1. **Classic** — dark round body `#151A30`→`#5A6694`, gray cap, curved fuse, sparking yellow tip `#FFC83D` (CPUParticles3D).
2. **Steel** — silver-blue sphere `#F2F6FF`→`#6C7BA8`, metal band (Torus), two side fins, dark cap.
3. **Tech** — teal sphere `#3CD8C8`→`#0E3A4A`, emissive lime ring `#B6F23C`, antenna with glowing tip.
4. **Gold Missile** — upright gold capsule `#FFE58A`→`#A86A10`, cone nose, two fins, orange stripe `#FF9A3D`, white gloss highlight.
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
15. **Omega Nuke** — biggest/brightest: rainbow-shifting core, crown of floating rings, trailing sparkles, subtle screen glow when merged.

All tier data (name, colors, income/sec, buy cost, build id) lives in
`resources`/`data/nuke_tiers.json` and the `NukeTier` resource.

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
- Big green `Buy Bomb  $120` button (`#3DDC5A`, 64px tall, white text, dark shadow, thick darker bottom edge, press animation).
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
- [ ] Step 1 — Environment, camera, baseplate, slots.
- [ ] Step 2 — Tier 1–6 bomb builders + debug gallery scene for all 15 tiers.
- [ ] Step 3 — Tier 7–15 bomb builders.
- [ ] Step 4 — 3D drag and drop, merge effects, bobbing/glow.
- [ ] Step 5 — Shared theme, HUD, Buy Bomb button, nav bar.
- [ ] Step 6 — Raid screen and 3D raid animation.
- [ ] Step 7 — Offline earnings popup.
- [ ] Step 8 — Performance pass, final validation.

## Notes
- Original names, art, and audio only. Fonts are SIL OFL licensed (license texts included in `assets/fonts/`).
- Android export and real-device testing remain.
