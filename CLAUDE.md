# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Cosmic Serpent**, created by Venkat Midhun Mareedu (`Config.AUTHOR` / `CREDIT_LINE`, shown on the menu, side panel and settings screen), is a space-themed snake game written in Godot 4.7 (GDScript) that uses the Forward+ renderer. Hitting a wall or the snake's own body kills it. The game has twelve power-ups, a combo multiplier and a neon glow look. It has no tests.

## Commands

- Run the game: `godot --path .`
- Open the editor: `godot -e --path .`
- Check for script and parse errors without a window: `godot --headless --path . --quit-after 600`. It prints nothing when everything is fine. The game starts in attract mode, so this exercises the simulation too.
- Re-import after adding assets: `godot --headless --import --path .`
- Release builds: `./build.sh` exports the `Linux` and `Windows` presets from `export_presets.cfg` as single-file executables with the PCK embedded. It then packages `build/CosmicSerpent-linux-x86_64.tar.gz` and `build/CosmicSerpent-windows-x86_64.zip`. It needs the 4.7.2 export templates in `~/.local/share/godot/export_templates/4.7.2.stable/`. Only `linux_release.x86_64` and `windows_release_x86_64.exe` are installed there. The player-facing install guide is `README.md`, which is also copied into both archives.

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
- Input goes through `Game._steer()` into `Snake.queue_direction()`, which buffers up to two turns and rejects reversals. If the first queued turn arrives once at least `EARLY_TURN_PROGRESS` of the step has elapsed, `_steer()` runs the tick immediately so there's no input lag. `SnakeView` then blends from the last drawn position (tracked with `early_steps`) to hide the jump.

**Attract mode:** the title screen runs a real game with `ai_mode = true`. `AiPilot` steers it using greedy pathing plus a flood-fill check for enough space. In this mode the HUD hides banners and the high score isn't saved. `State.MENU` runs the same simulation as `State.PLAYING`.

**Power-ups** live in `scripts/powerups/`:
- Each one extends `PowerUp` and sets `id`, `display_name`, `tagline`, `glyph`, `color` and `duration` in `_init()`. `duration` is `0` for instant effects and `INF` for effects that last until used.
- Global effects work through the modifier hooks `tick_factor()`, `score_factor()` and `warp_factor()`. `PowerUpManager` multiplies these across all active power-ups.
- Effects that change the board happen in `apply()` (for example, Supernova calls `game.spawn_bonus_burst`).
- `can_spawn(game)` limits when an orb may appear (for example, Molt needs a long enough snake). Quantum is a placeholder that `PowerUpManager.collect()` swaps for a random other type.
- Some effects are checked by id instead: `Game` checks `powerups.has(...)` for `phase`, `shield`, `gravity`, `wormhole` (wrapping goes through `Game.resolve()`, which `AiPilot` also uses), `lance` and `stasis`. `SnakeView` checks ids to choose palettes and overlays.
- To add a power-up, write the subclass, add it to `PowerUpManager.TYPES`, and add any id checks it needs. The HUD's field guide and the spawning code pick it up automatically.

**Rendering conventions:**
- `rendering/viewport/hdr_2d` is on, and the WorldEnvironment glow threshold is 1.0. Colors with any channel above 1.0 bloom; colors at or below 1.0 don't.
- The palette and all tuning constants (grid, pacing, combo, spawn timings) are in `scripts/config.gd`.
- Keep HUD text colors at or below about 1.2. The HUD layer is inside `background_canvas_max_layer`, so text brighter than that blurs.
- `Hud._soft()` turns an HDR power-up color into a readable text color.
- **Performance:** draw repeated shapes as textured quads (`Config.disc()` / `Config.soft_dot()` with `draw_texture_rect`), not `draw_circle(..., antialiased = true)`. Antialiased circles build geometry on the CPU. Hundreds of them per frame cost over 8 ms, which caused dropped frames and visible input lag.

**Assets:** the only file asset is the Orbitron font (`assets/fonts/`, SIL OFL). It is the project-wide GUI font, and the views also preload it for `draw_string`. `Sfx` synthesizes all audio in code, with no audio files.

**Audio (`scripts/sfx.gd`):**
- One `WorkerThreadPool` task renders everything. The effects are ready after about 0.8 s and the 8-bar synthwave music loop after about 3 s. Until then `play()` does nothing. `_exit_tree` sets `_cancelled` and waits for the task, so freeing the node mid-render doesn't crash.
- Every effect is normalized to the same peak. Per-sound loudness is set in the `GAIN` table.
- Power-up pickup sounds are keyed by power-up id, except the shield: its pickup is `shield_up`, and `shield` is the shield-breaking sound.
- During the attract demo only the `UI_SOUNDS` play.
- Buses are created in code: `SFX` (reverb), `Music` (a low-pass filter that `_process` opens while playing, with pitch changed by Hyperdrive and Time Warp) and a hard limiter on Master.
- Volume sliders map to `Sfx.volumes` (0..1, applied as amplitude v², defaults in `DEFAULT_VOLUMES`). They're edited in `SettingsPanel` (`scripts/settings_panel.gd`, opened with the `settings` action (Tab; O, 0 and keypad 0 also work, because Orbitron draws O and 0 almost identically) or the menu's SETTINGS button, from the menu, pause and game-over screens) and saved with the music on/off setting (M) in the `audio` section of the save file. While the panel is open, `Game._input` passes input through to the GUI, except for close keys.
- `Game._save_high_score()` loads the file before writing, so it keeps the other sections.
- **Testing:** driver scripts that run player mode save the real high score. Back up and restore `user://cosmic_serpent.cfg` around them.

**Persistence:** the high score is stored with `ConfigFile` at `user://cosmic_serpent.cfg` (on Linux, `~/.local/share/godot/app_userdata/Cosmic Serpent/`).
