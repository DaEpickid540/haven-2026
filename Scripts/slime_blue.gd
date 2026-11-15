extends CharacterBody2D

@export var speed := 45.0
@export var faces_right := false
@export var detected_range = 64.0
@export var stop_distance := 16.0
@export var max_health := 3
@export var contact_damage := 1.0
@export var attack_interval := 0.5

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback = animation_tree.get("parameters/StateMachine/playback") as AnimationNodeStateMachinePlayback
@onready var ray_cast_2d: RayCast2D = $RayCast2D
@onready var damage_area: Area2D = $DamageArea
@onready var animation_player: AnimationPlayer = $AnimationPlayer
var dying = false

var health: int
var _attack_cooldown := 0.0

func _ready() -> void:
	dying=false
	health = max_health

func _physics_process(delta: float) -> void:
	if dying:
		return

	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	velocity = Vector2.ZERO
	# Chase
	if can_see_player():
		var to_player := ray_cast_2d.global_transform.basis_xform(ray_cast_2d.target_position)
		if to_player.length() > stop_distance:
			velocity = to_player.normalized() * speed
		else:
			_try_attack_player(get_player())
		if to_player.x != 0.0:
			sprite_2d.scale.x = sign(to_player.x) * (1 if faces_right else -1)
	move_and_slide()
	damage_overlapping_player()

# Contact
func damage_overlapping_player() -> void:
	for other_area in damage_area.get_overlapping_areas():
		var player := other_area.get_parent() as Player
		if player != null and other_area.name == "Hurtbox":
			_try_attack_player(player)
			return

func get_player() -> Player:
	return get_tree().get_first_node_in_group("player")
	
func is_player_in_range() -> bool:
	var result = false
	var player: = get_player()
	
	if player is Player:
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player < detected_range:
			result = true
	return result
	
func can_see_player() ->bool:
	if not is_player_in_range():
		return false
	var player := get_player()
	ray_cast_2d.target_position = ray_cast_2d.to_local(player.global_position)
	ray_cast_2d.force_raycast_update()  # Refresh
	return not ray_cast_2d.is_colliding() or ray_cast_2d.get_collider() == player


func take_damage(amount: int) -> void:
	if dying:
		return

	health -= amount
	if health <= 0:
		dying = true
		Audio.play_sfx("enemy_die", 0.1)
		velocity = Vector2.ZERO
		animation_tree.active = false
		damage_area.set_deferred("monitoring", false)
		animation_player.play(&"death")
		await animation_player.animation_finished
		queue_free()
		return

	var flash := create_tween()
	flash.tween_property(sprite_2d, "modulate", Color(1, 0.35, 0.35), 0.08)
	flash.tween_property(sprite_2d, "modulate", Color.WHITE, 0.12)


func _on_damage_area_entered(other_area: Area2D) -> void:
	var player := other_area.get_parent() as Player
	if player != null and other_area.name == "Hurtbox":
		_try_attack_player(player)



func _try_attack_player(player: Player) -> void:
	if _attack_cooldown > 0.0:
		return

	_attack_cooldown = attack_interval
	player.take_damage(contact_damage)
