class_name RoomExit extends Area2D

## Walking into this loads target_scene and puts the player at the
## Entries marker named target_entry or the default spot if empty
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
	Transition.change_scene(target_scene)
