extends CanvasLayer

const NAMES := {
	"res://Scenes/dunegon_hub.tscn": "Hub",
	"res://Scenes/dungeon_room_1.tscn": "Dungeon 1",
	"res://Scenes/dungeon_room_2.tscn": "Dungeon 2",
	"res://Scenes/dungeon_room_3.tscn": "Dungeon 3",
}
const DELAY := 0.3
const FADE_IN := 0.25
const HOLD := 1.4
const FADE_OUT := 0.5
const SLIDE := 6.0
const TOP := 28.0

var _box := VBoxContainer.new()
var _title := Label.new()
var _rule := ColorRect.new()
var _tween: Tween = null


func _ready() -> void:
	layer = 2
	_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 3)
	_title.theme_type_variation = &"HudLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rule.custom_minimum_size = Vector2(0, 1)
	_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_rule.color = Color(1, 0.84706, 0.46667)
	_box.add_child(_title)
	_box.add_child(_rule)
	add_child(_box)
	_box.modulate.a = 0.0
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()


func show_name(text: String) -> void:
	if _tween != null:
		_tween.kill()
	_title.text = text
	_rule.custom_minimum_size.x = _title.get_theme_font("font").get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, _title.get_theme_font_size("font_size")).x + 16
	_box.position.y = TOP + SLIDE
	_box.modulate.a = 0.0
	# banner
	_tween = create_tween()
	_tween.tween_interval(DELAY)
	_tween.tween_property(_box, "modulate:a", 1.0, FADE_IN)
	_tween.parallel().tween_property(_box, "position:y", TOP, FADE_IN) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(HOLD)
	_tween.tween_property(_box, "modulate:a", 0.0, FADE_OUT)


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var text: String = NAMES.get(scene.scene_file_path, "")
	if text.is_empty():
		if _tween != null:
			_tween.kill()
		_box.modulate.a = 0.0
		return
	show_name(text)
