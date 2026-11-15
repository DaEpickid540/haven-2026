class_name RoomExit extends Area2D

## Walking into this switches to `target_scene` and puts the player at the
## `Entries/<target_entry>` marker there (or the default spot if empty).
@export_file("*.tscn") var target_scene: String
@export var target_entry: String

static var pending_entry := ""

var _used := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _used or not body.is_in_group("Player") or target_scene.is_empty():
		return
	_used = true
	RoomExit.pending_entry = target_entry
	# Deferred: changing scenes inside a physics callback is not allowed.
	get_tree().change_scene_to_file.call_deferred(target_scene)
