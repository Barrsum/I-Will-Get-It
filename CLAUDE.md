# I Will Get It — project guide for Claude

A full commercial-quality PC game (Windows, macOS, Linux) built in **Godot 4.7.1**.
Goal: anyone in the world can pick it up, enjoy it, and have a good time. No slop, no cheap shortcuts.
We work **one step at a time, studio style**: plan → build → playtest → polish → commit.

Repo: https://github.com/Barrsum/I-Will-Get-It (branch `main`)

## The game

**Premise.** A boy (the hero) finally asked out the girl he loves — she said yes. The night before the
date, he and his best friend (the bro) climb a nearby hill to watch a once-in-1000-years magical
shooting-star cluster. The hero won't stop talking about her, making absurd promises:

> "No matter if the earth is on fire, I will spend every last breath of my life only protecting and being there for her."

…"I'll slay the dragon, fight the alien monsters, climb the mountains, run through the forest…"
The comet passes overhead and **grants every boast literally**. Now he must do all of it to make it to the date.

**Structure.**
- Every level = one boast from the opening scene. Each level has its **own mechanics, objective and camera**,
  each inspired by a classic game/genre (Mario-style platformer, Sonic-style speed run, car race,
  Souls-like boss, shooter, stealth, etc.).
- The hero travels **alone**. The **bro stays on the hill**, can magically see him, and helps **by voice only**
  (radio-style guidance, tutorials, jokes, story). He is the game's narrator and emotional glue.
- Ending: the hero reaches the date.
- Names of hero / girl / bro: **TBD**. Final level list: **TBD** (see `docs/` once the design doc exists).

## Core technical direction

- **3D everywhere, camera/movement locked per level.** 2D-style levels (platformer, speed run) use 3D models
  with a side camera and movement constrained to a plane (2.5D). Top-down for racing, free 3D camera for
  Souls-like, etc. One art pipeline (Blender → `.glb`) serves every level.
- Renderer: **Forward+** (desktop). Base resolution 1920×1080, `canvas_items` stretch, `expand` aspect.
- Language: **GDScript** (statically typed — always annotate types and return types).
- Shared systems (build once, reuse in every level): player/character base, bro dialogue/voice system,
  checkpoint + death/retry flow, input mapping (keyboard + gamepad), save system, scene transitions, settings.
- Each level adds its own mechanics on top of the shared systems; levels must not fork the core.

## Layout

```
assets/      models (.glb), textures, materials, shaders, fonts, audio/{music,sfx,voice}
scenes/      boot/, ui/, characters/, levels/<level_name>/  (scene + its level-specific scripts together)
scripts/     shared code; scripts/autoload/ for singletons (registered in project.godot)
addons/      third-party Godot plugins (check license first)
docs/        design doc, level specs, decisions
```

- Files/folders: `snake_case`. Classes (`class_name`): `PascalCase`. Signals: past tense (`died`, `level_completed`).
- Keep a scene and its script side by side (`player.tscn` + `player.gd`).

## Commands

Godot binaries live in `C:\Godot\` (use the `_console` one from the CLI so output is captured):
`C:\Godot\Godot_v4.7.1-stable_win64_console.exe` — editor GUI: `C:\Godot\Godot_v4.7.1-stable_win64.exe`

- Import / validate project: `<godot> --headless --import` (run from repo root)
- Smoke-run main scene: `<godot> --headless --quit-after 3`
- Run a specific scene: `<godot> --headless --quit-after 60 res://scenes/levels/<x>/<x>.tscn`
- Open editor: `<godot> -e`

After changing scenes/scripts, run the import + smoke-run to catch parse/load errors before reporting done.

## Rules

- **Licensing:** we may borrow/learn from open-source projects (movement, cameras, etc.). Only copy code/assets
  under **MIT, BSD, Zlib, Apache-2.0, CC0, CC-BY** (record CC-BY attribution). **Never GPL/LGPL/CC-NC/CC-ND.**
  Log every third-party item in `CREDITS.md` with source URL + license.
- **No IP copying:** levels are *inspired by* genres/feel. No Nintendo/Sega/etc. characters, names, art, music or sounds.
- **3D assets:** made with the user via Blender MCP, exported as `.glb` into `assets/models/`. Don't commit `.blend1` backups.
- **Git:** small, focused commits with clear messages; push to `origin main` when a step is finished.
  Large binaries (big audio/video/.blend) may need Git LFS later — raise it before adding them.
- The user drives direction; propose, explain trade-offs, then build. Keep the user in the loop each step.

## Status / roadmap

- [x] Project initialised (Godot 4.7.1, Forward+, folder structure, boot placeholder)
- [x] Git + GitHub set up
- [ ] Game design doc (`docs/game_design.md`): story beats, names, level list, controls, art/tone direction
- [ ] Core systems prototype (player controller, camera modes, bro dialogue, death/retry)
- [ ] First level to full quality (the bar for all others)
- [ ] Remaining levels, one at a time
- [ ] Menus, settings, save, audio pass
- [ ] Export presets + builds for Windows / macOS / Linux, release
