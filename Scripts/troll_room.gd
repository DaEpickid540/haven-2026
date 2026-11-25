extends "res://Scripts/dungeon_room.gd"

# banner waits until the player is out of the fake corridor
const REVEAL_Y := 24.0

var _revealed := false


func _physics_process(_delta: float) -> void:
	if _revealed or $Player.global_position.y < REVEAL_Y:
		return
	_revealed = true
	RoomBanner.show_name("Bad Idea")
