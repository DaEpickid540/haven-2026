extends Node

const FLASH_SHADER := preload("res://Scripts/flash.gdshader")
const FLASH_TIME := 0.12
const SHAKE_MAX := 6.0
const SHAKE_DECAY := 1.5
const NUMBER_RISE := 14.0
const NUMBER_TIME := 0.6

const ENEMY_HIT := Color(1, 1, 1)
const PLAYER_HIT := Color(1, 0.35, 0.35)
const HEAL := Color(0.45, 1, 0.5)

var _trauma := 0.0
var _camera: Camera2D = null


# combo
func hit(sprite: CanvasItem, amount: int, color := ENEMY_HIT, trauma := 0.25) -> void:
	flash(sprite)
	number(sprite.global_position, amount, color)
	shake(trauma)


func flash(sprite: CanvasItem) -> void:
	if not is_instance_valid(sprite):
		return
	var mat := sprite.material as ShaderMaterial
	if mat == null or mat.shader != FLASH_SHADER:
		mat = ShaderMaterial.new()
		mat.shader = FLASH_SHADER
		sprite.material = mat
	if sprite.has_meta(&"flash_tween"):
		var old: Tween = sprite.get_meta(&"flash_tween")
		if old != null and old.is_valid():
			old.kill()
	mat.set_shader_parameter("flash", 1.0)
	var tween := sprite.create_tween()
	tween.tween_property(mat, "shader_parameter/flash", 0.0, FLASH_TIME)
	sprite.set_meta(&"flash_tween", tween)


func shake(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func number(world_pos: Vector2, amount: int, color := ENEMY_HIT) -> void:
	popup(world_pos, str(amount), color)


func popup(world_pos: Vector2, text: String, color := ENEMY_HIT) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"HudLabel"
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(32, 10)
	label.z_index = 100
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = world_pos + Vector2(-16 + randf_range(-4, 4), -22)
	scene.add_child(label)
	# float
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - NUMBER_RISE, NUMBER_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, NUMBER_TIME * 0.4) \
		.set_delay(NUMBER_TIME * 0.6)
	tween.tween_callback(label.queue_free)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera != _camera:
		if is_instance_valid(_camera):
			_camera.offset = Vector2.ZERO
		_camera = camera
	if _camera == null or _trauma <= 0.0:
		return
	_trauma = maxf(_trauma - SHAKE_DECAY * delta, 0.0)
	if _trauma == 0.0:
		_camera.offset = Vector2.ZERO
		return
	var power := _trauma * SHAKE_MAX
	_camera.offset = (Vector2.from_angle(randf() * TAU) * power).round()
