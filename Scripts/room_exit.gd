class_name RoomExit extends Area2D

## Drop this on a doorway: when the player walks into it, the game switches to
## `target_scene`. The target scene places its own Player at its entry point.
@export_file("*.tscn") var target_scene: String

var _used := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _used or not body.is_in_group("Player") or target_scene.is_empty():
		return
	_used = true
	# Deferred: changing scenes inside a physics callback is not allowed.
	get_tree().change_scene_to_file.call_deferred(target_scene)
