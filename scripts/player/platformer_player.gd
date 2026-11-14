class_name PlatformerPlayer
extends CharacterBody2D
## Side-view platformer controller.
## Features: acceleration/friction, jump defined by height + time (easy to tune),
## coyote time, jump buffering, variable jump height, air jumps, dash,
## drop-through one-way platforms (down + jump), knockback on hurt().
##
## Expects a child AnimatedSprite2D with animations: idle, run, jump, fall, hurt
## (every character in assets/sprites/characters/*_frames.tres has these).

signal jumped
signal landed
signal dashed
signal hurt_started

@export_group("Run")
@export var max_speed := 110.0
@export var acceleration := 900.0
@export var friction := 1200.0
@export var air_acceleration := 700.0
@export var air_friction := 300.0

@export_group("Jump")
## Peak height of a full jump, in pixels (16 px = 1 tile).
@export var jump_height := 50.0
## Seconds to reach the peak.
@export var time_to_apex := 0.36
## Seconds to fall back down from the peak (shorter = snappier).
@export var time_to_land := 0.28
@export var max_fall_speed := 320.0
## Velocity multiplier when jump is released early (lower = shorter hops).
@export_range(0.0, 1.0) var jump_cut := 0.45
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12
@export var extra_air_jumps := 1

@export_group("Dash")
@export var dash_enabled := true
@export var dash_speed := 260.0
@export var dash_duration := 0.14
@export var dash_cooldown := 0.45

@export_group("Feel")
@export var sounds_enabled := true
@export var dust_effects := true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var facing := 1.0
var controls_enabled := true

var _jump_velocity: float
var _jump_gravity: float
var _fall_gravity: float
var _coyote_timer := 0.0
var _buffer_timer := 0.0
var _air_jumps_left := 0
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _hurt_timer := 0.0
var _was_on_floor := true
var _step_timer := 0.0

const DUST := preload("res://assets/sprites/effects/dust_frames.tres")


func _ready() -> void:
	_recalculate_jump()


## Call after changing jump_height / time_to_apex / time_to_land at runtime.
func _recalculate_jump() -> void:
	_jump_velocity = -2.0 * jump_height / time_to_apex
	_jump_gravity = 2.0 * jump_height / (time_to_apex * time_to_apex)
	_fall_gravity = 2.0 * jump_height / (time_to_land * time_to_land)


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	var dir := Input.get_axis("move_left", "move_right") if _can_control() else 0.0

	# --- timers -----------------------------------------------------------
	_coyote_timer = coyote_time if on_floor else _coyote_timer - delta
	_buffer_timer -= delta
	_dash_cooldown_timer -= delta
	_hurt_timer -= delta
	if on_floor:
		_air_jumps_left = extra_air_jumps
	if _can_control() and Input.is_action_just_pressed("jump"):
		_buffer_timer = jump_buffer_time

	# --- dash -------------------------------------------------------------
	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = Vector2(facing * dash_speed, 0.0)
		move_and_slide()
		_update_animation(on_floor, dir)
		return
	if dash_enabled and _can_control() and Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0.0:
		_dash_timer = dash_duration
		_dash_cooldown_timer = dash_cooldown
		if dir != 0.0:
			facing = signf(dir)
		_sfx("dash")
		dashed.emit()

	# --- gravity ----------------------------------------------------------
	if not on_floor:
		var g := _jump_gravity if velocity.y < 0.0 else _fall_gravity
		velocity.y = minf(velocity.y + g * delta, max_fall_speed)

	# --- jumping ----------------------------------------------------------
	if _buffer_timer > 0.0:
		if on_floor and Input.is_action_pressed("move_down"):
			position.y += 2.0  # drop through one-way platform
			_buffer_timer = 0.0
		elif _coyote_timer > 0.0:
			_jump(false)
		elif _air_jumps_left > 0:
			_air_jumps_left -= 1
			_jump(true)
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut

	# --- horizontal -------------------------------------------------------
	var accel: float
	if on_floor:
		accel = acceleration if dir != 0.0 else friction
	else:
		accel = air_acceleration if dir != 0.0 else air_friction
	if _hurt_timer <= 0.0:
		velocity.x = move_toward(velocity.x, dir * max_speed, accel * delta)
	if dir != 0.0:
		facing = signf(dir)

	move_and_slide()

	# --- landing ----------------------------------------------------------
	on_floor = is_on_floor()
	if on_floor and not _was_on_floor:
		landed.emit()
		_sfx("land", -6.0)
		_dust()
	_was_on_floor = on_floor

	if on_floor and absf(velocity.x) > 20.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.28
			if sounds_enabled:
				AudioManager.play_random_sfx(["footstep_1", "footstep_2", "footstep_3"], -10.0, 0.1)

	_update_animation(on_floor, dir)


func _jump(air: bool) -> void:
	velocity.y = _jump_velocity * (0.9 if air else 1.0)
	_buffer_timer = 0.0
	_coyote_timer = 0.0
	_sfx("double_jump" if air else "jump_1", -4.0)
	if not air:
		_dust()
	jumped.emit()


## Knock the player back. Call from enemies/hazards: player.hurt(enemy.global_position)
func hurt(from_position: Vector2 = global_position, knockback := 160.0) -> void:
	if _hurt_timer > 0.0:
		return
	_hurt_timer = 0.35
	var away := signf(global_position.x - from_position.x)
	velocity = Vector2((away if away != 0.0 else -facing) * knockback, -knockback * 0.8)
	_sfx("hurt_1")
	hurt_started.emit()


func is_hurt() -> bool:
	return _hurt_timer > 0.0


func _can_control() -> bool:
	return controls_enabled and _hurt_timer <= 0.0


func _update_animation(on_floor: bool, dir: float) -> void:
	sprite.flip_h = facing < 0.0
	var anim := &"idle"
	if _hurt_timer > 0.0:
		anim = &"hurt"
	elif _dash_timer > 0.0:
		anim = &"run"
	elif not on_floor:
		anim = &"jump" if velocity.y < 0.0 else &"fall"
	elif absf(velocity.x) > 5.0 or dir != 0.0:
		anim = &"run"
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)


func _sfx(name: String, volume_db := 0.0) -> void:
	if sounds_enabled:
		AudioManager.play_sfx(name, volume_db, 0.05)


func _dust() -> void:
	if not dust_effects or get_parent() == null:
		return
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = DUST
	fx.global_position = global_position + Vector2(0, 2)
	fx.animation_finished.connect(fx.queue_free)
	get_parent().add_child(fx)
	fx.play(&"default")
