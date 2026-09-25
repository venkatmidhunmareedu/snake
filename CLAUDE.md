# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Cosmic Serpent**: a space-themed snake game written in Godot 4.7 (GDScript) that uses the Forward+ renderer. Hitting a wall or the snake's own body kills it. The game has six power-ups, a combo multiplier and a neon glow look. It has no tests.

## Commands

- Run the game: `godot --path .`
- Open the editor: `godot -e --path .`
- Check for script and parse errors without a window: `godot --headless --path . --quit-after 600`. It prints nothing when everything is fine. The game starts in attract mode, so this exercises the simulation too.
- Re-import after adding assets: `godot --headless --import --path .`

## Architecture

**Everything is built in code.** `scenes/main.tscn` is only a `Node2D` with `scripts/game.gd` attached. `Game._build_scene()` creates the whole tree in this order:
1. WorldEnvironment (glow)
2. Camera2D (screen shake)
3. Nebula shader rect
4. `StarfieldView`
5. Grid shader rect
6. `BoardView`
7. `ItemView`
8. `SnakeView`
9. `Fx`
10. `Sfx`
11. A CanvasLayer holding `Hud`

The order of creation is the draw order. There are no other scenes, and there are no image or audio assets.

**Logic is separate from views.** `Game` owns all state (the `Snake`, `PowerUpManager`, foods, score, combo and the `State` enum). Each view has a `game: Game` reference and redraws from that state every frame in `_draw()`. Views never change game state. `Game` calls `fx.*`, `hud.banner/flash` and `sfx.play` directly for one-shot events.

**Simulation:**
- Gameplay advances on a fixed tick in `Game._simulate()`, which uses a time accumulator rather than a `Timer`.
- The interval is `tick_interval()`: base speed minus a speed-up per food eaten, times the product of `tick_factor()` over the active power-ups.
- `Snake` keeps `prev_body`, and the views interpolate from it to `body` using `game.tick_progress`, so movement looks smooth even though the logic moves one cell at a time.
- Input goes through `Snake.queue_direction()`, which buffers up to two turns and rejects reversals.

**Attract mode:** the title screen runs a real game with `ai_mode = true`. `AiPilot` steers it using greedy pathing plus a flood-fill check for enough space. In this mode the HUD hides banners and the high score isn't saved. `State.MENU` runs the same simulation as `State.PLAYING`.

**Power-ups** live in `scripts/powerups/`:
- Each one extends `PowerUp` and sets `id`, `display_name`, `tagline`, `glyph`, `color` and `duration` in `_init()`. `duration` is `0` for instant effects and `INF` for effects that last until used.
- Global effects work through the modifier hooks `tick_factor()`, `score_factor()` and `warp_factor()`. `PowerUpManager` multiplies these across all active power-ups.
- Effects that change the board happen in `apply()` (for example, Supernova calls `game.spawn_bonus_burst`).
- Some effects are checked by id instead: `Game` checks `powerups.has(&"phase" | &"shield" | &"gravity")`, and `SnakeView` checks ids to choose palettes and overlays.
- To add a power-up, write the subclass, add it to `PowerUpManager.TYPES`, and add any id checks it needs. The HUD's field guide and the spawning code pick it up automatically.

**Rendering conventions:**
- `rendering/viewport/hdr_2d` is on, and the WorldEnvironment glow threshold is 1.0. Colors with any channel above 1.0 bloom; colors at or below 1.0 don't.
- The palette and all tuning constants (grid, pacing, combo, spawn timings) are in `scripts/config.gd`.
- Keep HUD text colors at or below about 1.2. The HUD layer is inside `background_canvas_max_layer`, so text brighter than that blurs.
- `Hud._soft()` turns an HDR power-up color into a readable text color.

**Assets:** the only file asset is the Orbitron font (`assets/fonts/`, SIL OFL). It is the project-wide GUI font, and the views also preload it for `draw_string`. `Sfx` synthesizes every sound into an `AudioStreamWAV` at startup.

**Persistence:** the high score is stored with `ConfigFile` at `user://cosmic_serpent.cfg` (on Linux, `~/.local/share/godot/app_userdata/Cosmic Serpent/`).
