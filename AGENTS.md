# AGENTS.md — Merge-a-Nuke

## Game Concept
Android idle merge-and-raid game (Godot 4.x, GDScript, Mobile renderer).

- Merge bombs on a board into **15 tiers** of increasingly powerful bombs.
- The top tier (nuke) generates **cash per second**, including while the game is closed (offline earnings).
- **Raid** AI bases to steal their cash.
- **Lock** your base with a **timed shield** to protect it from raids.
- **Redeem codes** for rewards.
- **Daily rewards** for returning players.

## Folder Structure
- `scenes/` — Godot scenes (`.tscn`).
- `scripts/` — GDScript source (`.gd`).
- `resources/` — Godot `Resource` files (`.tres`) for game data.
- `data/` — JSON data files (tiers, upgrades, codes, missions, balance).
- `assets/` — Original art and audio only (no third-party copyrighted content).
- `addons/` — Editor plugins (e.g. Funplay MCP).

## Coding Rules (all future work)
1. Use **static typing** in GDScript; comment non-obvious logic.
2. Keep game data (tiers, upgrades, codes, missions, balance) in **Resources or JSON**, never hardcoded in scripts.
3. After every change run `godot --headless --path . --quit` and fix **all** errors before continuing.
4. Run `git init` (once) and **commit after each phase**.

## Phase Checklist
Update this list after every phase (mark `[x]` when complete).

- [x] Phase 0 — Project setup: Godot version verified, project settings configured (portrait 1080x1920, canvas_items stretch, expand aspect, Mobile renderer, emulate mouse from touch), folder structure created, AGENTS.md written.
- [x] Phase 1 — Core merge loop: NukeTier resource + 15-tier data, GameState autoload, BaseScreen with 6 slots, buy/auto-spawn, drag-and-drop merge with feedback.
- [x] Phase 2 - Economy & saving: Economy autoload, big-number formatting, safe-area HUD, upgrades JSON + screen, SaveManager (versioned atomic save, autosave, offline earnings + welcome popup), AdService stub.
- [x] Phase 3 - Raiding and base lock: RaidService (AI targets), RaidScreen with raid sequence, revenge raids, Lock Base with persisted shield.
- [x] Phase 4 - Navigation, UI, and settings: Main shell with bottom nav, ShopScreen, SettingsScreen, AudioManager, theme, button press animations.
- [ ] Phase 5 — Economy: cash/sec and offline earnings.
- [ ] Phase 6 — Raid system (attack AI bases, steal cash).
- [ ] Phase 7 — Base shield (timed protection).
- [ ] Phase 8 — Codes & daily rewards.
- [ ] Phase 9 — Polish, Android export, and release readiness.

## Notes
- Gameplay is intentionally **not** implemented yet; only setup is complete.
- Use original names, art, and audio only.