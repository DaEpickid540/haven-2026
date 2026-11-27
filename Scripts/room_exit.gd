class_name RoomExit extends Area2D

@export_file("*.tscn") var target_scene: String
@export var target_entry: String
# swap scenes with no fade so it doesnt feel like a door
@export var seamless := false

static var pending_entry := ""
# where the player was relative to the exit so a seamless swap lines up
static var pending_offset := Vector2.ZERO
# no banner
static var seamless_swap := false

var _used := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _used or not body.is_in_group("Player") or target_scene.is_empty():
		return
	_used = true
	RoomExit.pending_entry = target_entry
	if seamless:
		RoomExit.pending_offset = body.global_position - global_position
		RoomExit.seamless_swap = true
		get_tree().change_scene_to_file.call_deferred(target_scene)
	else:
		Transition.change_scene(target_scene)
