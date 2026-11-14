extends Node2D
## Asset showcase / test level. Builds the map from ASCII so it's easy to edit,
## and lets you flip through every theme, character and music track live.
##
##   1-5  switch tileset theme      C  next character      M  next music track
##   Tab  switch platformer <-> top-down demo        H  hide this help text
##
## You can delete this whole folder (scenes/demo + scripts/demo) once you start
## the real game - nothing else depends on it.

@export var top_down := false

const THEMES := ["grassland", "desert", "snow", "dungeon", "scifi"]
const THEME_MUSIC := {
	"grassland": "adventure_theme", "desert": "desert_wind", "snow": "winter_village",
	"dungeon": "dungeon_crawl", "scifi": "space_station",
}
const THEME_CLEAR := {
	"grassland": Color("3e8948"), "desert": Color("c28569"), "snow": Color("8b9bb4"),
	"dungeon": Color("181425"), "scifi": Color("181425"),
}
const CHARACTERS := ["adventurer", "knight", "wizard", "ninja", "robot", "astronaut"]
const MUSIC := ["adventure_theme", "calm_menu", "dungeon_crawl", "space_station",
	"boss_battle", "desert_wind", "winter_village", "puzzle_groove"]

const COIN_FRAMES := preload("res://assets/sprites/items/coin_frames.tres")
const FLAG_FRAMES := preload("res://assets/sprites/items/flag_frames.tres")
const SPARKLE_FRAMES := preload("res://assets/sprites/effects/sparkle_frames.tres")

# Legend:  #=ground  ==one-way platform  B=crate  ^=spikes  c=coin  P=player  F=goal flag
#          t f r b L s = decorations (tuft, plant, rock, bush, light, sign)   D=door
const PLATFORMER_MAP := [
	"................................................................",
	"................................................................",
	"................................................................",
	"...........................................c.c.c................",
	"..........................................=======...............",
	"...............................c.c.c............................",
	"...........c.c.c..............=======.............c.c.c.........",
	"..........=======.................................#####.........",
	"..................................................#####.........",
	"...................B..............................#####.....D...",
	"..P..s..t.f......BBB...L...b..r.....^^^....c.c....#####.L.t...F.",
	"#########################.....##################################",
	"#########################.....##################################",
	"#########################.....##################################",
]

# Legend:  #=wall  .=floor  ,=path  T=tiles  c=coin  P=player  f r b L s=decor
const TOPDOWN_MAP := [
	"########################################",
	"#......................................#",
	"#..f.......,,,,,,,,,,,,,,,.........r...#",
	"#..........,TTTTTTTTTTTTT,.............#",
	"#...####...,TTTTc.c.cTTTT,.............#",
	"#...####...,TTTTTTTTTTTTT,......####...#",
	"#..........,,,,,,,,P,,,,,,......####...#",
	"#..................,...................#",
	"#....b.............,..........c.c.c....#",
	"#..s...............,...............L...#",
	"#..........r.......,......f............#",
	"#.....c.c.c........,...........b.......#",
	"#..L...............,...................#",
	"########################################",
]

const DECOR := {"t": Vector2i(0, 2), "f": Vector2i(1, 2), "r": Vector2i(2, 2),
	"b": Vector2i(3, 2), "L": Vector2i(4, 2), "s": Vector2i(5, 2)}

@onready var ground: TileMapLayer = $Ground
@onready var decor: TileMapLayer = $Decor
@onready var background: Node2D = $Background
@onready var player: CharacterBody2D = $Player
@onready var pickups: Node2D = $Pickups
@onready var coin_label: Label = $HUD/CoinLabel
@onready var info_label: Label = $HUD/InfoLabel

var theme_index := 0
var character_index := 0
var music_index := -1
var coins := 0
var total_coins := 0
var spawn := Vector2.ZERO
var won := false


func _ready() -> void:
	_build_map(TOPDOWN_MAP if top_down else PLATFORMER_MAP)
	background.visible = not top_down
	_apply_theme()
	_update_hud()


func _physics_process(_delta: float) -> void:
	if not top_down:
		var bottom := (PLATFORMER_MAP.size() + 2) * 16
		if player.global_position.y > bottom:
			_respawn()
		_check_spikes()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.physical_keycode
	if key >= KEY_1 and key <= KEY_5:
		theme_index = key - KEY_1
		_apply_theme()
	elif key == KEY_C:
		character_index = (character_index + 1) % CHARACTERS.size()
		player.get_node("AnimatedSprite2D").sprite_frames = load(
			"res://assets/sprites/characters/%s_frames.tres" % CHARACTERS[character_index])
		AudioManager.play_sfx("ui_confirm")
	elif key == KEY_M:
		music_index = (music_index + 1) % MUSIC.size()
		AudioManager.play_music(MUSIC[music_index], 0.5)
	elif key == KEY_H:
		info_label.visible = not info_label.visible
	elif key == KEY_TAB:
		var next := "topdown_demo" if not top_down else "platformer_demo"
		get_tree().change_scene_to_file("res://scenes/demo/%s.tscn" % next)
	else:
		return
	_update_hud()


# --- map building ------------------------------------------------------------

func _build_map(rows: Array) -> void:
	var at := func(x: int, y: int) -> String:
		if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].length():
			return "#" if top_down else "."
		return rows[y][x]

	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			var cell := Vector2i(x, y)
			var center := Vector2(x * 16 + 8, y * 16 + 8)
			var h := absi(hash(cell)) % 100
			if top_down and ch != "#":
				var floor_tile := Vector2i(0, 3) if h > 15 else Vector2i(1, 3)
				if ch == ",":
					floor_tile = Vector2i(3, 3)
				elif ch == "T":
					floor_tile = Vector2i(2, 3)
				ground.set_cell(cell, 0, floor_tile)
			match ch:
				"#":
					ground.set_cell(cell, 0, _wall_tile(at, x, y) if top_down else _ground_tile(at, x, y, h))
				"=":
					var l: bool = at.call(x - 1, y) == "="
					var r: bool = at.call(x + 1, y) == "="
					ground.set_cell(cell, 0, Vector2i(5 if l and r else (4 if r else 6), 0))
				"B":
					ground.set_cell(cell, 0, Vector2i(7, 0))
				"^":
					decor.set_cell(cell, 0, Vector2i(7, 1))
				"D":
					decor.set_cell(cell, 0, Vector2i(6, 2))
					decor.set_cell(cell + Vector2i(0, 1), 0, Vector2i(7, 2))
				"c":
					_add_coin(center)
				"F":
					_add_flag(center)
				"P":
					spawn = center
					player.global_position = spawn
				_:
					if DECOR.has(ch):
						decor.set_cell(cell, 0, DECOR[ch])

	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = 0
	cam.limit_top = 0 if top_down else -200
	cam.limit_right = rows[0].length() * 16
	cam.limit_bottom = rows.size() * 16


func _ground_tile(at: Callable, x: int, y: int, h: int) -> Vector2i:
	var l: bool = at.call(x - 1, y) == "#"
	var r: bool = at.call(x + 1, y) == "#"
	var top: bool = at.call(x, y - 1) != "#"
	if top:
		if not l and not r:
			return Vector2i(3, 0)
		return Vector2i(0, 0) if not l else (Vector2i(2, 0) if not r else Vector2i(1, 0))
	if not l:
		return Vector2i(0, 1)
	if not r:
		return Vector2i(2, 1)
	return Vector2i(3, 1) if h < 12 else Vector2i(1, 1)


func _wall_tile(at: Callable, x: int, y: int) -> Vector2i:
	# Wall "top" if there is more wall below it, otherwise the brick "face".
	return Vector2i(5, 3) if at.call(x, y + 1) == "#" else Vector2i(6, 3)


# --- pickups -----------------------------------------------------------------

func _add_coin(pos: Vector2) -> void:
	var area := _make_area(pos, 5.0)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = COIN_FRAMES
	spr.autoplay = "spin"
	area.add_child(spr)
	area.body_entered.connect(func(body: Node) -> void:
		if body == player:
			coins += 1
			AudioManager.play_sfx("coin_1", -4.0, 0.03)
			_spawn_fx(SPARKLE_FRAMES, pos)
			area.queue_free()
			_update_hud())
	total_coins += 1


func _add_flag(pos: Vector2) -> void:
	var area := _make_area(pos, 8.0)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = FLAG_FRAMES
	spr.autoplay = "wave"
	area.add_child(spr)
	area.body_entered.connect(func(body: Node) -> void:
		if body == player and not won:
			won = true
			AudioManager.play_sfx("level_complete")
			_update_hud())


func _make_area(pos: Vector2, radius: float) -> Area2D:
	var area := Area2D.new()
	area.position = pos
	area.collision_layer = 8   # pickups
	area.collision_mask = 2    # player
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	pickups.add_child(area)
	return area


func _spawn_fx(frames: SpriteFrames, pos: Vector2) -> void:
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = frames
	fx.position = pos
	fx.animation_finished.connect(fx.queue_free)
	add_child(fx)
	fx.play(&"default")


# --- hazards -----------------------------------------------------------------

func _check_spikes() -> void:
	var feet := player.global_position + Vector2(0, 6)
	var data := decor.get_cell_tile_data(decor.local_to_map(feet))
	if data and data.get_custom_data("type") == "hazard" and player.has_method("hurt"):
		player.call("hurt", feet + Vector2(0, 8))


func _respawn() -> void:
	AudioManager.play_sfx("hurt_2")
	player.global_position = spawn
	player.velocity = Vector2.ZERO
	player.get_node("Camera2D").reset_smoothing()


# --- theme / hud -------------------------------------------------------------

func _apply_theme() -> void:
	var t: String = THEMES[theme_index]
	var tileset: TileSet = load("res://assets/sprites/tiles/%s_tileset.tres" % t)
	ground.tile_set = tileset
	decor.tile_set = tileset
	for layer_name in ["sky", "far", "near"]:
		var spr: Sprite2D = background.get_node(layer_name.capitalize() + "/Sprite2D")
		spr.texture = load("res://assets/sprites/backgrounds/%s_%s.png" % [t, layer_name])
	RenderingServer.set_default_clear_color(THEME_CLEAR[t])
	music_index = MUSIC.find(THEME_MUSIC[t])
	AudioManager.play_music(THEME_MUSIC[t], 0.6)


func _update_hud() -> void:
	coin_label.text = "Coins %d/%d%s" % [coins, total_coins, "   GOAL!" if won else ""]
	var move := "WASD/Arrows move  Shift dash" + ("" if top_down else "  Space jump (x2)")
	info_label.text = "%s\n1-5 theme: %s   C char: %s\nM music: %s   Tab: %s   H: hide" % [
		move, THEMES[theme_index], CHARACTERS[character_index],
		MUSIC[music_index] if music_index >= 0 else "-",
		"platformer" if top_down else "top-down"]
