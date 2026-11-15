extends CharacterBody2D

const SPEED = 30.0

@export var detected_range = 64
@export var stop_distance := 16.0
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
	damage_area.area_entered.connect(_on_damage_area_entered)

func _physics_process(delta: float) -> void:
	if !dying:
		var state = playback.get_current_node()
		match state:
			"Idle":
				pass
			"Chase":
				var player = get_player()
				if player is Player:
					var direction := global_position.direction_to(player.global_position)
					var distance_to_player := global_position.distance_to(player.global_position)
					if distance_to_player >= stop_distance:
						velocity = direction * SPEED
					else:
						velocity = Vector2.ZERO
					if direction.x != 0.0:
						sprite_2d.scale.x = sign(direction.x) * -1
				else:
					velocity = Vector2.ZERO
				move_and_slide()
	else:
		animation_player.play("death")
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
		print("ah")
	var player := get_player()
	ray_cast_2d.target_position = player.global_position - global_position
	var player_in_sight = not ray_cast_2d.is_colliding()
	return player_in_sight


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


func _on_damage_area_entered(other_area: Area2D) -> void:
	velocity = Vector2.ZERO
	var player := other_area.get_parent() as Player
	if player != null and other_area.name == "Hurtbox":
		player.take_damage(contact_damage)
	
