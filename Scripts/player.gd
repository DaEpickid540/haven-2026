class_name Player extends CharacterBody2D

const DASH_MULTIPLIER := 1.3
const HURT_COOLDOWN := 0.6

var dashing := false
var stamina := 10.0
var input_vector := Vector2.ZERO
var _hurt_timer := 0.0

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback := animation_tree.get("parameters/StateMachine/playback") as AnimationNodeStateMachinePlayback


func _ready() -> void:
	PlayerStats.died.connect(_on_died)


func take_damage(amount: int) -> void:
	if _hurt_timer > 0.0:
		return
	_hurt_timer = HURT_COOLDOWN
	PlayerStats.take_damage(amount)
	var flash := create_tween()
	flash.tween_property($Sprite2D, "modulate", Color(1, 0.3, 0.3), 0.08)
	flash.tween_property($Sprite2D, "modulate", Color.WHITE, 0.2)


func _on_died() -> void:
	set_physics_process(false)
	$DeathScreen.open()


func _physics_process(delta: float) -> void:
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)
	if playback.get_current_node() == "MoveState":
		move_state()
	else:
		input_vector = Vector2.ZERO
	var speed := PlayerStats.get_move_speed() * (DASH_MULTIPLIER if dashing else 1.0)
	velocity = input_vector * speed
	move_and_slide()


func move_state() -> void:
	input_vector = Input.get_vector("left", "right", "up", "down")
	dashing = Input.is_action_pressed("dash")
	if input_vector != Vector2.ZERO:
		update_blend_positions(Vector2(input_vector.x, -input_vector.y))
	if Input.is_action_just_pressed("attack"):
		playback.travel("AttackState")


func update_blend_positions(direction: Vector2) -> void:
	animation_tree.set("parameters/StateMachine/MoveState/RunState/blend_position", direction)
	animation_tree.set("parameters/StateMachine/MoveState/StandState/blend_position", direction)
	animation_tree.set("parameters/StateMachine/AttackState/blend_position", direction)
