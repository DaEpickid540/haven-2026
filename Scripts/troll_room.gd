extends "res://Scripts/dungeon_room.gd"

# banner waits until the player is out of the fake corridor
const REVEAL_Y := 24.0

const COIN_DROP_CHANCE := 0.25

var _revealed := false


func _ready() -> void:
	super()
	# stingy
	for enemy in $Enemies.get_children():
		if "coin_drop_chance" in enemy:
			enemy.coin_drop_chance = COIN_DROP_CHANCE


func _physics_process(_delta: float) -> void:
	if _revealed or $Player.global_position.y < REVEAL_Y:
		return
	_revealed = true
	RoomBanner.show_name("Bad Idea")
