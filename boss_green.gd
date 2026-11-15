extends CharacterBody2D

@export var max_health := 10
@export var contact_damage := 1       # Damage if player touches it while walking/idle (optional)
@export var attack_damage := 3       # Damage dealt by the ranged pound attack
@export var attack_range := 65.0     # Maximum distance the pound attack reaches
@export var attack_interval := 5.0   # Time between pound attacks
@export var loot_rewarded := 5

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var damage_area: Area2D = $DamageArea

var health: int
var dying = false
var is_attacking = false
var _attack_timer := 0.0

func _ready() -> void:
	dying = false
	health = max_health
	
	# Fixes spritesheet centering by shifting it up by 16 pixels
	if animated_sprite_2d:
		animated_sprite_2d.position.y = -16

func _physics_process(delta: float) -> void:
	if dying:
		return

	# If the boss is currently performing its pound attack, stay still and skip tracking
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Accumulate time toward the next 5-second pound attack
	_attack_timer += delta
	if _attack_timer >= attack_interval:
		_attack_timer = 0.0
		execute_pound_attack()
		return

	# Stay completely in place and play idle animation
	velocity = Vector2.ZERO
	animated_sprite_2d.play("idle")
	
	# Optional: face the player while standing still
	var player = get_player()
	if player:
		var dir_x = player.global_position.x - global_position.x
		if dir_x != 0:
			animated_sprite_2d.scale.x = sign(dir_x) * abs(animated_sprite_2d.scale.x)

	move_and_slide()
	damage_overlapping_player()

func execute_pound_attack() -> void:
	is_attacking = true
	velocity = Vector2.ZERO
	
	# 1. Play jump_up animation
	animated_sprite_2d.play("jump_up")
	await animated_sprite_2d.animation_finished
	
	# 2. Pause briefly in the air at the apex
	await get_tree().create_timer(0.3).timeout
	
	# 3. Play pound animation, shake screen, and deal damage at range
	animated_sprite_2d.play("pound")
	trigger_screenshake()
	check_and_damage_player_in_range()
	
	await animated_sprite_2d.animation_finished
	is_attacking = false

func check_and_damage_player_in_range() -> void:
	var player = get_player()
	if player and is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		if distance <= attack_range:
			player.take_damage(attack_damage)

func trigger_screenshake() -> void:
	var cam = get_viewport().get_camera_2d()
	if cam:
		var tween = create_tween()
		for i in range(4):
			var random_offset = Vector2(randf_range(-6, 6), randf_range(-6, 6))
			tween.tween_property(cam, "offset", random_offset, 0.03)
		tween.tween_property(cam, "offset", Vector2.ZERO, 0.03)

func get_player() -> Player:
	return get_tree().get_first_node_in_group("player")

func damage_overlapping_player() -> void:
	for other_area in damage_area.get_overlapping_areas():
		var player := other_area.get_parent() as Player
		if player != null and other_area.name == "Hurtbox":
			player.take_damage(contact_damage)
			return

func take_damage(amount: int) -> void:
	if dying:
		return

	health -= amount
	if health <= 0:
		dying = true
		velocity = Vector2.ZERO
		damage_area.set_deferred("monitoring", false)
		PlayerStats.add_coins(loot_rewarded)
		animated_sprite_2d.play("death")
		
		await animated_sprite_2d.animation_finished
		queue_free()
		return

	# Flash red when taking damage
	var flash := create_tween()
	flash.tween_property(animated_sprite_2d, "modulate", Color(1, 0.35, 0.35), 0.08)
	flash.tween_property(animated_sprite_2d, "modulate", Color.WHITE, 0.12)

func _on_damage_area_entered(other_area: Area2D) -> void:
	var player := other_area.get_parent() as Player
	if player != null and other_area.name == "Hurtbox":
		player.take_damage(contact_damage)
