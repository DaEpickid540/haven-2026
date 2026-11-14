class_name Slime
extends CharacterBody2D

enum State {IDLE, CHASE, ATTACK, HURT, DEAD}

@export_category("Detection")
@export var detection_radius = 96.0
@export var attack_range = 18.0

@export_category("Movement")
@export var chase_speed := 20.0

@export_category("Combat")
@export var max_health := 3
@export var attack_duration := 0.45
@export var hurt_duration := 0.22

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var state := State.IDLE
var target: Node2D
var health: int
var state_timer := 0.0
var facing_left := false


func _ready() -> void:
	health = max_health
	_find_player()
	_enter_state(State.IDLE)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if not is_instance_valid(target):
		target = null
		_find_player()

	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			if _can_detect_target():
				_enter_state(State.CHASE)

		State.CHASE:
			_update_chase()

		State.ATTACK:
			velocity = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				_enter_state(State.CHASE if _can_detect_target() else State.IDLE)

		State.HURT:
			velocity = Vector2.ZERO
			state_timer -= delta
			if state_timer <= 0.0:
				_enter_state(State.CHASE if _can_detect_target() else State.IDLE)

	move_and_slide()


func take_damage(amount := 1) -> void:
	if state == State.DEAD:
		return

	health -= amount
	if health <= 0:
		_enter_state(State.DEAD)
	else:
		_enter_state(State.HURT)


func _update_chase() -> void:
	if not _can_detect_target():
		_enter_state(State.IDLE)
		return

	var direction := global_position.direction_to(target.global_position)
	if direction.x != 0.0:
		facing_left = direction.x < 0.0
		sprite.flip_h = facing_left

	if global_position.distance_to(target.global_position) <= attack_range:
		_enter_state(State.ATTACK)
		return

	velocity = direction * chase_speed


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		target = players.front() as Node2D


func _can_detect_target() -> bool:
	return is_instance_valid(target) and global_position.distance_to(target.global_position) <= detection_radius


func _enter_state(next_state: State) -> void:
	if state == next_state and animation_player.is_playing():
		return

	state = next_state
	match state:
		State.IDLE:
			animation_player.play("idle")
		State.CHASE:
			animation_player.play("chase")
		State.ATTACK:
			state_timer = attack_duration
			animation_player.play("attack")
		State.HURT:
			state_timer = hurt_duration
			animation_player.play("hurt")
		State.DEAD:
			velocity = Vector2.ZERO
			animation_player.play("death")
			set_physics_process(false)
