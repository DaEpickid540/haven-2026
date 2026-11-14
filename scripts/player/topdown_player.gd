class_name TopDownPlayer
extends CharacterBody2D
## 8-direction top-down controller (Zelda / twin-stick style).
## Features: acceleration/friction, normalized diagonals, dash, knockback on hurt().
## Expects a child AnimatedSprite2D with animations: idle, run (optional: hurt).

signal dashed
signal hurt_started

@export var max_speed := 90.0
@export var acceleration := 900.0
@export var friction := 1000.0

@export_group("Dash")
@export var dash_enabled := true
@export var dash_speed := 240.0
@export var dash_duration := 0.15
@export var dash_cooldown := 0.5

@export_group("Feel")
@export var sounds_enabled := true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

## Last non-zero movement direction (handy for aiming attacks / interactions).
var facing := Vector2.DOWN
var controls_enabled := true

var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _hurt_timer := 0.0
var _step_timer := 0.0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func _physics_process(delta: float) -> void:
	_dash_cooldown_timer -= delta
	_hurt_timer -= delta
	var input := Vector2.ZERO
	if controls_enabled and _hurt_timer <= 0.0:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		facing = input.normalized()

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = facing * dash_speed
	elif dash_enabled and controls_enabled and Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0.0:
		_dash_timer = dash_duration
		_dash_cooldown_timer = dash_cooldown
		velocity = facing * dash_speed
		if sounds_enabled:
			AudioManager.play_sfx("dash", 0.0, 0.05)
		dashed.emit()
	elif _hurt_timer <= 0.0:
		var rate := acceleration if input != Vector2.ZERO else friction
		velocity = velocity.move_toward(input * max_speed, rate * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * 0.5 * delta)

	move_and_slide()

	if velocity.length() > 20.0 and _dash_timer <= 0.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.3
			if sounds_enabled:
				AudioManager.play_random_sfx(["footstep_1", "footstep_2", "footstep_3"], -10.0, 0.1)

	_update_animation()


func hurt(from_position: Vector2 = global_position, knockback := 150.0) -> void:
	if _hurt_timer > 0.0:
		return
	_hurt_timer = 0.3
	var away := (global_position - from_position).normalized()
	velocity = (away if away != Vector2.ZERO else -facing) * knockback
	if sounds_enabled:
		AudioManager.play_sfx("hurt_1", 0.0, 0.05)
	hurt_started.emit()


func _update_animation() -> void:
	if absf(facing.x) > 0.1:
		sprite.flip_h = facing.x < 0.0
	var anim := &"idle"
	if _hurt_timer > 0.0:
		anim = &"hurt"
	elif velocity.length() > 5.0:
		anim = &"run"
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)
