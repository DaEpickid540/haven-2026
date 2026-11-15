class_name Player extends CharacterBody2D

var speed = 100.0
var strength = 10.0
var dashing = false
var stamina = 10.0

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback = animation_tree.get("parameters/StateMachine/playback") as AnimationNodeStateMachinePlayback
@onready var weapon_hitbox: Area2D = $WeaponHitbox


var input_vector = Vector2.ZERO

const SPEED = 100.0
const HURT_COOLDOWN := 0.6

var _hurt_timer := 0.0
var _enemies_hit_this_attack: Array[Node2D] = []


func _ready() -> void:
	PlayerStats.died.connect(_on_died)
	weapon_hitbox.body_entered.connect(_on_weapon_body_entered)


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
	if _hurt_timer > 0.0:
		_hurt_timer = maxf(_hurt_timer - delta, 0.0)

	var state = playback.get_current_node()
	match state:
		"MoveState":
			move_state(delta)
		"AttackState":
			input_vector = Vector2.ZERO
		
		
	velocity = input_vector * speed
	move_and_slide()

func move_state(delta: float) -> void:
	input_vector = Input.get_vector("left","right","up","down")
			
	if input_vector != Vector2.ZERO:
		var direction_vector = Vector2(input_vector.x, -input_vector.y)
		update_blend_positions(direction_vector)
		
	if Input.is_action_just_pressed("attack"):
		_start_attack()
	if Input.is_action_pressed("dash"):
		speed=130.0
		dashing=true
	else: 
		speed=100.0
		dashing=false
		


func update_blend_positions(direction_vector: Vector2) -> void:
	animation_tree.set("parameters/StateMachine/MoveState/RunState/blend_position",direction_vector)
	animation_tree.set("parameters/StateMachine/MoveState/StandState/blend_position", direction_vector)
	animation_tree.set("parameters/StateMachine/AttackState/blend_position", direction_vector)


func _start_attack() -> void:
	_enemies_hit_this_attack.clear()
	playback.travel("AttackState")


func _on_weapon_body_entered(body: Node2D) -> void:
	if playback.get_current_node() != "AttackState":
		return
	if body in _enemies_hit_this_attack or not body.has_method("take_damage"):
		return

	_enemies_hit_this_attack.append(body)
	body.take_damage(PlayerStats.get_damage())
