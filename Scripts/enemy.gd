extends CharacterBody2D

const SPEED = 30.0

@export var detected_range = 64
@export var stop_distance := 10.0
@export var max_health := 3
@export var contact_damage := 1

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback = animation_tree.get("parameters/StateMachine/playback") as AnimationNodeStateMachinePlayback
@onready var ray_cast_2d: RayCast2D = $RayCast2D
@onready var damage_area: Area2D = $DamageArea
@onready var animation_player: AnimationPlayer = $AnimationPlayer
var dying = false

var health: int

func _ready() -> void:
	dying=false
	health = max_health

func _physics_process(delta: float) -> void:
	if dying:
		animation_player.play("death")
		return

	# Movement is driven directly by the raycast line of sight, so the enemy
	# moves along the same ray that is drawn with "Visible Collision Shapes".
	if can_see_player():
		var to_player := ray_cast_2d.global_transform.basis_xform(ray_cast_2d.target_position)
		var direction := to_player.normalized()
		if to_player.length() >= stop_distance:
			velocity = direction * SPEED
		else:
			velocity = Vector2.ZERO
		if direction.x != 0.0:
			sprite_2d.scale.x = sign(direction.x) * -1
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	damage_overlapping_player()

# Deal contact damage every frame the player's Hurtbox overlaps, not only on
# entry, so the slime keeps hurting the player while chasing/touching them.
# The player's own HURT_COOLDOWN limits how often this lands.
func damage_overlapping_player() -> void:
	for other_area in damage_area.get_overlapping_areas():
		var player := other_area.get_parent() as Player
		if player != null and other_area.name == "Hurtbox":
			player.take_damage(contact_damage)
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
	# target_position is in the raycast's local space.
	ray_cast_2d.target_position = ray_cast_2d.to_local(player.global_position)
	# Refresh the ray now; otherwise is_colliding() reports last frame's target.
	ray_cast_2d.force_raycast_update()
	if not ray_cast_2d.is_colliding():
		return true
	# Hitting the player itself still counts as seeing them.
	return ray_cast_2d.get_collider() == player


func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		dying=true
		velocity = Vector2.ZERO
		animation_player.play("death")
		await get_tree().create_timer(1.0).timeout
		queue_free()
		return

	var flash := create_tween()
	flash.tween_property(sprite_2d, "modulate", Color(1, 0.35, 0.35), 0.08)
	flash.tween_property(sprite_2d, "modulate", Color.WHITE, 0.12)
	
