extends CharacterBody2D

@export var max_health := 18
@export var contact_damage := 1    
@export var contact_knockback_force := 180.0  # Adjustable knockback strength
@export var attack_damage := 3    
@export var attack_range := 65.0   
@export var attack_interval := 5.0 
@export var loot_rewarded := 5

const WIN_SCREEN := preload("res://Scenes/win_screen.tscn")
const WIN_DELAY := 0.6

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var damage_area: Area2D = $DamageArea

var health: int
var dying = false
var is_attacking = false
var _attack_timer := 0.0

func _ready() -> void:
	dying = false
	health = max_health
	
	if animated_sprite_2d:
		animated_sprite_2d.position.y = 0

func _physics_process(delta: float) -> void:
	if dying:
		return

	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_attack_timer += delta
	if _attack_timer >= attack_interval:
		_attack_timer = 0.0
		execute_pound_attack()
		return

	velocity = Vector2.ZERO
	animated_sprite_2d.play("idle")
	
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
	
	animated_sprite_2d.position.y = -16
	animated_sprite_2d.play("jump_up")
	await animated_sprite_2d.animation_finished
	
	await get_tree().create_timer(0.3).timeout
	
	animated_sprite_2d.play("pound")
	
	await animated_sprite_2d.animation_finished
	animated_sprite_2d.position.y = 0
	animated_sprite_2d.play("idle")
	is_attacking = false
	trigger_screenshake()
	check_and_damage_player_in_range()

func check_and_damage_player_in_range() -> void:
	var player = get_player()
	if player and is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		if distance <= attack_range:
			player.take_damage(attack_damage, global_position)

func trigger_screenshake() -> void:
	Juice.shake(0.9)

func get_player() -> Player:
	return get_tree().get_first_node_in_group("player")

func damage_overlapping_player() -> void:
	for other_area in damage_area.get_overlapping_areas():
		var player := other_area.get_parent() as Player
		if player != null and other_area.name == "Hurtbox":
			apply_contact_to_player(player)
			return

func apply_contact_to_player(player: Player) -> void:
	if not player.take_damage(contact_damage):
		return

	# Calculate vector pointing from enemy to player
	var push_dir = (player.global_position - global_position).normalized()
	if push_dir == Vector2.ZERO:
		push_dir = Vector2.RIGHT

	player.knockback(push_dir * contact_knockback_force)

func take_damage(amount: int) -> void:
	if dying:
		return

	health -= amount
	Juice.hit(animated_sprite_2d, amount, Juice.ENEMY_HIT, 0.35)
	if health <= 0:
		dying = true
		velocity = Vector2.ZERO
		damage_area.set_deferred("monitoring", false)
		PlayerStats.add_coins(loot_rewarded)
		animated_sprite_2d.play("death")

		await animated_sprite_2d.animation_finished
		hide()
		await get_tree().create_timer(WIN_DELAY, false).timeout
		var player := get_player()
		if player == null or player.dying:
			queue_free()
			return
		var win := WIN_SCREEN.instantiate()
		get_tree().current_scene.add_child(win)
		win.open()
		queue_free()
		return

func _on_damage_area_entered(other_area: Area2D) -> void:
	var player := other_area.get_parent() as Player
	if player != null and other_area.name == "Hurtbox":
		apply_contact_to_player(player)
