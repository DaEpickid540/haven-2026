extends Node2D

## The hub's exit is the top edge: walking above EXIT_Y asks the player
## (LeaveHubModal) whether to enter the dungeon or stay.
const EXIT_Y := 0.0
const STAY_PUSHBACK := 12.0  # how far below the exit "Stay" puts the player
const DUNGEON_SCENE := "res://Scenes/dungeon_room_1.tscn"  # TODO: confirm the first dungeon scene

@onready var player: CharacterBody2D = $Player

signal begin_descent

var _was_past_exit := false


func _process(_delta: float) -> void:
	# Fire once when the player crosses the exit, not every frame they're past it.
	var past_exit := player.global_position.y < EXIT_Y
	if past_exit and not _was_past_exit:
		begin_descent.emit()
	_was_past_exit = past_exit


func _on_leave_hub_modal_entered() -> void:
	get_tree().change_scene_to_file(DUNGEON_SCENE)


func _on_leave_hub_modal_stayed() -> void:
	# Step the player back inside so the pop-up doesn't reopen straight away.
	player.global_position.y = EXIT_Y + STAY_PUSHBACK
	player.velocity = Vector2.ZERO
	_was_past_exit = false
