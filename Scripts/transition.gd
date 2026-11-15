extends CanvasLayer

## Fades to black then swaps the scene then fades back in
##     Transition.change_scene("res://Scenes/dungeon_room_2.tscn")

const FADE_TIME := 0.25

var _black := ColorRect.new()
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_black.color = Color.BLACK
	_black.modulate.a = 0.0
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_black)


func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = true
	await _fade_to(1.0)
	get_tree().change_scene_to_file(path)
	await get_tree().scene_changed
	get_tree().paused = false
	await _fade_to(0.0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_black, "modulate:a", alpha, FADE_TIME)
	await tween.finished
