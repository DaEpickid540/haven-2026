extends Node2D

const EXIT_Y := 0.0
const STAY_PUSHBACK := 12.0
const DUNGEON_SCENE := "res://Scenes/dungeon_room_1.tscn"  # todo

@onready var player: CharacterBody2D = $Player

signal begin_descent

var _was_past_exit := false


func _process(_delta: float) -> void:
	var past_exit := player.global_position.y < EXIT_Y
	if past_exit and not _was_past_exit:
		begin_descent.emit()
	_was_past_exit = past_exit


func _ready() -> void:
	PlayerStats.heal_up_to(PlayerStats.HUB_HEAL_FRACTION)
	PlayerStats.last_scene = scene_file_path


func _on_leave_hub_modal_entered() -> void:
	Transition.change_scene(DUNGEON_SCENE)


func _on_leave_hub_modal_stayed() -> void:
	player.global_position.y = EXIT_Y + STAY_PUSHBACK
	player.velocity = Vector2.ZERO
	_was_past_exit = false
