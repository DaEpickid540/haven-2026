class_name Player extends CharacterBody2D

var speed = 100.0
var strength = 10.0

const DASH_MULTIPLIER := 1.3
const HURT_COOLDOWN := 0.6
const SPRINT_DRAIN := 30.0
const STAMINA_REGEN := 20.0
const SPRINT_RECOVER := 0.25
const DEATH_TIME_SCALE := 0.5

var dashing := false
var stamina := 0.0
var input_vector := Vector2.ZERO
var _hurt_timer := 0.0
var _exhausted := false
var dying := false

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback = animation_tree.get("parameters/StateMachine/playback") as AnimationNodeStateMachinePlayback
@onready var weapon_hitbox: Area2D = $WeaponHitbox
@onready var animation_player: AnimationPlayer = $AnimationPlayer



const SPEED = 100.0

var _enemies_hit_this_attack: Array[Node2D] = []


func _ready() -> void:
	stamina = PlayerStats.get_max_stamina()
	PlayerStats.died.connect(_on_died)
	weapon_hitbox.body_entered.connect(_on_weapon_body_entered)


func take_damage(amount: int) -> void:
	if _hurt_timer > 0.0:
		return
	_hurt_timer = HURT_COOLDOWN
	Audio.play_sfx("hurt")
	PlayerStats.take_damage(amount)
	var flash := create_tween()
	flash.tween_property($Sprite2D, "modulate", Color(1, 0.3, 0.3), 0.08)
	flash.tween_property($Sprite2D, "modulate", Color.WHITE, 0.2)


func _on_died() -> void:
	if dying:
		return

	dying = true
	Audio.play_sfx("player_die")
	set_physics_process(false)
	velocity = Vector2.ZERO
	animation_tree.active = false
	Engine.time_scale = DEATH_TIME_SCALE
	animation_player.play("death")
	await get_tree().create_timer(0.4).timeout
	Engine.time_scale = 1.0
	$DeathScreen.open()


func _exit_tree() -> void:
	if dying:
		Engine.time_scale = 1.0

func _physics_process(delta: float) -> void:
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)
	var state = playback.get_current_node()
	match state:
		"MoveState":
			move_state(delta)
		"AttackState":
			input_vector = Vector2.ZERO
			dashing = false
		_:
			input_vector = Vector2.ZERO
			dashing = false
	update_stamina(delta)
	var speed := PlayerStats.get_move_speed() * (DASH_MULTIPLIER if dashing else 1.0)
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
		


		
func update_stamina(delta: float) -> void:
	var max_stamina := PlayerStats.get_max_stamina()
	if stamina >= max_stamina * SPRINT_RECOVER:
		_exhausted = false
	dashing = dashing and not _exhausted and input_vector != Vector2.ZERO
	if dashing:
		stamina = maxf(stamina - SPRINT_DRAIN * delta, 0.0)
		_exhausted = stamina == 0.0
	else:
		stamina = minf(stamina + STAMINA_REGEN * delta, max_stamina)
	$Hud.set_dash(stamina, max_stamina)


func update_blend_positions(direction: Vector2) -> void:
	animation_tree.set("parameters/StateMachine/MoveState/RunState/blend_position", direction)
	animation_tree.set("parameters/StateMachine/MoveState/StandState/blend_position", direction)
	animation_tree.set("parameters/StateMachine/AttackState/blend_position", direction)


func _start_attack() -> void:
	_enemies_hit_this_attack.clear()
	Audio.play_sfx("swing", 0.08)
	playback.travel("AttackState")


		
func _on_weapon_body_entered(body: Node2D) -> void:
	if not "Attack" in playback.get_current_node():
		return
	if body in _enemies_hit_this_attack or not body.has_method("take_damage"):
		return

	_enemies_hit_this_attack.append(body)
	Audio.play_sfx("hit", 0.1)
	print($"Hit {body}]")
	body.take_damage(PlayerStats.get_damage())

	_enemies_hit_this_attack.append(body)
	body.take_damage(PlayerStats.get_damage())
