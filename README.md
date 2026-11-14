# Haven 2026 – Game Jam Starter (Godot 4.7)

Theme-agnostic starter kit: placeholder art for 5 settings, a pile of retro SFX,
8 looping music tracks, and ready-to-use platformer + top-down player controllers.

**Run it:** open `project.godot` in Godot 4.7 and press F5. The demo level lets you preview everything:

| Key | Action |
| --- | --- |
| WASD / Arrows | Move |
| Space / Z | Jump (press again in the air for a double jump; Down + Jump drops through platforms) |
| Shift / X | Dash |
| 1–5 | Switch theme: grassland, desert, snow, dungeon, sci-fi |
| C | Switch character |
| M | Next music track |
| Tab | Switch between the platformer and top-down demos |
| H | Hide the help text |

Gamepads work too: the d-pad or left stick moves, A jumps, X dashes, and Start pauses.

## Layout

```
assets/
  sprites/
    characters/   adventurer, knight, wizard, ninja, robot, astronaut   (16x16, idle/run/jump/fall/hurt)
    enemies/      slime x4 colours, bat, ghost, drone, eyeball, spider, skeleton, zombie
    tiles/        <theme>_tileset.png + .tres  (grassland, desert, snow, dungeon, scifi)
    items/        coin, hearts, gems x5, keys x3, potions x4, chests, star, bomb, sword, bow,
                  shield, mushroom, apple, battery, scroll, checkpoint flag, spring
    ui/           hearts (full/half/empty), buttons, panels, bars, cursor, crosshair,
                  checkboxes, arrows, ui_theme.tres
    effects/      explosion, dust, sparkle, hit, smoke, magic_burst, splat, heal
    projectiles/  bullet, arrow, lasers x3, fireball, magic_orb, energy_ball
    backgrounds/  <theme>_sky / _far / _near parallax layers (320x180, tile horizontally)
  sounds/         55 SFX: jump, land, footsteps, coins, powerups, hurt, explosions, lasers,
                  UI clicks, doors, jingles (level_complete, game_over, victory_fanfare)...
  music/          adventure_theme, calm_menu, dungeon_crawl, space_station, boss_battle,
                  desert_wind, winter_village, puzzle_groove  (seamless loops)
scenes/
  player/         platformer_player.tscn, topdown_player.tscn
  demo/           showcase levels (safe to delete later)
scripts/
  player/         platformer_player.gd, topdown_player.gd
  autoload/       audio_manager.gd  (global "AudioManager")
tools/asset_gen/  Python scripts that generated all the art and audio
```

## Using the stuff

**Animated sprites:** every animated sheet has a matching `*_frames.tres`. Drag it into an
`AnimatedSprite2D`'s *Sprite Frames* slot. To change the player's look, swap the frames on the
player's `AnimatedSprite2D` for another file in `characters/`.

**Tilesets:** every theme uses the same 8x4 atlas layout, so a level painted with one theme can
switch to another just by changing the `TileMapLayer`'s `tile_set`.

| Row | Tiles |
| --- | --- |
| 0 | ground top (left, mid, right, single), one-way platform (left, mid, right), crate |
| 1 | ground fill (left, mid, right, variant), wall, background wall, ladder, spikes |
| 2 | 6 decorations, door top, door bottom |
| 3 | top-down: 3 floors, path, liquid, wall top, wall face, pit |

The solid tiles already have collision, and the platforms are one-way. Special tiles carry a
`type` custom-data string that you can read with `tile_data.get_custom_data("type")`. The
values are `ladder`, `hazard`, `liquid`, `pit`, `door`, and `crate`.

**Audio:**
```gdscript
AudioManager.play_sfx("coin_1")
AudioManager.play_sfx("hit_1", -3.0, 0.1)       # volume dB, random pitch ±10%
AudioManager.play_music("boss_battle")          # crossfades + loops
AudioManager.set_bus_volume("Music", 0.5)       # Music / SFX buses exist already
```

**Players:** every tuning value is an `@export` you can change in the Inspector: speed,
acceleration, jump height and timing, coyote time, jump buffer, air jumps, and dash. Enemies
and hazards can call `player.hurt(source_position)` to knock the player back.

**Input actions** (Project Settings → Input Map): `move_left/right/up/down`, `jump`, `dash`,
`attack` (J / left mouse button), `interact` (E / Enter), `pause` (Esc).

**Physics layers:** 1 world, 2 player, 3 enemies, 4 pickups, 5 hazards.

## Regenerating / tweaking assets

The art and audio are made by code that only needs Python 3 (no extra packages). To change a
palette, a melody seed, or a sound, edit the matching file in `tools/asset_gen/` and run:

```bash
python tools/asset_gen/generate_all.py            # everything
python tools/asset_gen/generate_all.py sfx        # just sounds (or: sprites, music)
```

All assets are original and generated for this project, so you can use them freely in the jam.
