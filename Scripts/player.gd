class_name Player extends CharacterBody2D

var speed = 80.0
var strength = 10.0

const SPRINT_MULTIPLIER := 1.3
const DASH_SPEED := 260.0
const DASH_TIME := 0.15
const DASH_COOLDOWN := 0.35
const DASH_COST := 20.0
const GHOST_INTERVAL := 0.04
const GHOST_FADE := 0.2
const HURT_COOLDOWN := 0.6
const SPRINT_DRAIN := 30.0
const STAMINA_REGEN := 20.0
const SPRINT_RECOVER := 0.25
const DEATH_TIME_SCALE := 0.5
const KNOCKBACK_FORCE := 120.0
const KNOCKBACK_DECAY := 700.0
const GRAVE_SCENE := preload("res://Scenes/grave.tscn")

var sprinting := false
var stamina := 0.0
var input_vector := Vector2.ZERO
var _hurt_timer := 0.0
var _exhausted := false
var _knockback := Vector2.ZERO
var dying := false
var _dash_timer := 0.0
var _dash_cooldown := 0.0
var _dash_direction := Vector2.ZERO
var _facing := Vector2.DOWN
var _ghost_timer := 0.0

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
	_spawn_grave.call_deferred()


# grave from the last death if it was in this room
func _spawn_grave() -> void:
	if owner == null or PlayerStats.grave_scene.is_empty():
		return
	if PlayerStats.grave_scene != owner.scene_file_path:
		return
	var grave := GRAVE_SCENE.instantiate()
	owner.add_child(grave)
	# under the player and enemies
	owner.move_child(grave, get_index())
	grave.global_position = PlayerStats.grave_position


func take_damage(amount: int, from := Vector2.INF, source := "") -> bool:
	if _hurt_timer > 0.0 or dying or _dash_timer > 0.0:
		return false
	_hurt_timer = HURT_COOLDOWN
	Audio.play_sfx("hurt")
	Juice.hit($Sprite2D, amount, Juice.PLAYER_HIT, 0.5)
	if from != Vector2.INF:
		knockback((global_position - from).normalized() * KNOCKBACK_FORCE)
	PlayerStats.take_damage(amount, source)
	return true


func knockback(force: Vector2) -> void:
	_knockback = force


func _on_died() -> void:
	if dying:
		return

	dying = true
	if owner != null:
		PlayerStats.record_death(owner.scene_file_path, global_position)
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
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	if _dash_timer > 0.0:
		dash_state(delta)
		return
	var state = playback.get_current_node()
	match state:
		"MoveState":
			move_state(delta)
		"AttackState":
			input_vector = Vector2.ZERO
			sprinting = false
		_:
			input_vector = Vector2.ZERO
			sprinting = false
	update_stamina(delta)
	var speed := PlayerStats.get_move_speed() * (SPRINT_MULTIPLIER if sprinting else 1.0)
	velocity = input_vector * speed + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	move_and_slide()

func move_state(delta: float) -> void:
	input_vector = Input.get_vector("left","right","up","down")
			
	if input_vector != Vector2.ZERO:
		_facing = input_vector.normalized()
		var direction_vector = Vector2(input_vector.x, -input_vector.y)
		update_blend_positions(direction_vector)
		
	sprinting = Input.is_action_pressed("sprint")
	if Input.is_action_just_pressed("attack"):
		_start_attack()
	elif Input.is_action_just_pressed("dash"):
		_start_dash()


func _start_dash() -> void:
	if _dash_cooldown > 0.0 or stamina < DASH_COST:
		return
	stamina -= DASH_COST
	_dash_timer = DASH_TIME
	_dash_cooldown = DASH_TIME + DASH_COOLDOWN
	_dash_direction = _facing
	_ghost_timer = 0.0
	_knockback = Vector2.ZERO
	sprinting = false
	# keeps the run animation going
	input_vector = _dash_direction
	Audio.play_sfx("swing", 0.15)
	$Hud.set_stamina(stamina, PlayerStats.get_max_stamina())


func dash_state(delta: float) -> void:
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_ghost_timer = GHOST_INTERVAL
		_spawn_ghost()
	velocity = _dash_direction * DASH_SPEED
	move_and_slide()


func _spawn_ghost() -> void:
	var sprite: Sprite2D = $Sprite2D
	var ghost := sprite.duplicate() as Sprite2D
	get_parent().add_child(ghost)
	ghost.global_position = sprite.global_position
	ghost.modulate.a = 0.5
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, GHOST_FADE)
	tween.tween_callback(ghost.queue_free)


		
func update_stamina(delta: float) -> void:
	var max_stamina := PlayerStats.get_max_stamina()
	if stamina >= max_stamina * SPRINT_RECOVER:
		_exhausted = false
	sprinting = sprinting and not _exhausted and input_vector != Vector2.ZERO
	if sprinting:
		stamina = maxf(stamina - SPRINT_DRAIN * delta, 0.0)
		_exhausted = stamina == 0.0
	else:
		stamina = minf(stamina + STAMINA_REGEN * delta, max_stamina)
	$Hud.set_stamina(stamina, max_stamina)


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
	body.take_damage(PlayerStats.get_damage())
