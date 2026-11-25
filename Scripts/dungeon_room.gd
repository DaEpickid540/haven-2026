extends Node2D


func _ready() -> void:
	var entry := RoomExit.pending_entry
	var offset := RoomExit.pending_offset
	RoomExit.pending_entry = ""
	RoomExit.pending_offset = Vector2.ZERO
	var marker := get_node_or_null("Entries/" + entry) as Node2D
	if entry.is_empty() or marker == null:
		return
	$Player.global_position = marker.global_position + offset
	$Player/Camera2D.reset_smoothing()
