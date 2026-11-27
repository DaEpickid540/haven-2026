extends "res://Scripts/dungeon_room.gd"

# banner waits until the player is out of the fake corridor
const REVEAL_Y := 24.0

const COIN_DROP_CHANCE := 0.25
const KICK_SCENE := "res://Scenes/dungeon_room_1.tscn"
const KICK_DELAY := 1.5

var _revealed := false
var _kicked := false


func _ready() -> void:
	super()
	# stingy
	for enemy in $Enemies.get_children():
		if "coin_drop_chance" in enemy:
			enemy.coin_drop_chance = COIN_DROP_CHANCE


func _physics_process(_delta: float) -> void:
	_check_cleared()
	if _revealed or $Player.global_position.y < REVEAL_Y:
		return
	_revealed = true
	RoomBanner.show_name("Bad Idea")


# softlock
func _check_cleared() -> void:
	if _kicked or $Enemies.get_child_count() > 0 or $Player.dying:
		return
	_kicked = true
	RoomBanner.show_name("Fine. Start over.")
	await get_tree().create_timer(KICK_DELAY, false).timeout
	if not $Player.dying:
		Transition.change_scene(KICK_SCENE)
