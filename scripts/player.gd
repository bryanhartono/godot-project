extends CharacterBody2D

const BASE_HP = 100
const BASE_FIRE_RATE = 0.5

@export var player_id: int = 1
@export var character_index: int = 0  # 0=Blue 1=Red 2=Green 3=Grey

const PASSIVES = [
	{"fire_rate_mult": 0.7, "aoe_mult": 1.0, "heal_on_kill": 0,  "hp_bonus": 0},
	{"fire_rate_mult": 1.0, "aoe_mult": 1.5, "heal_on_kill": 0,  "hp_bonus": 0},
	{"fire_rate_mult": 1.0, "aoe_mult": 1.0, "heal_on_kill": 5,  "hp_bonus": 0},
	{"fire_rate_mult": 1.0, "aoe_mult": 1.0, "heal_on_kill": 0,  "hp_bonus": 50},
]

const CHARACTER_FRAMES: Array = [
	preload("res://resources/player_blue_frames.tres"),
	preload("res://resources/player_red_frames.tres"),
	preload("res://resources/player_green_frames.tres"),
	preload("res://resources/player_grey_frames.tres"),
]

var max_hp: int = BASE_HP
var hp: int = BASE_HP
var fire_rate: float = BASE_FIRE_RATE
var speed: float = 120.0
var damage_mult: float = 1.0
var aoe_mult: float = 1.0
var heal_on_kill: int = 0
var owned_upgrade_tags: Array[String] = []
var is_ghost: bool = false

var _fire_timer: float = 0.0
var _chain_counter: int = 0
var _is_dead: bool = false
var _revive_cooldown: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var revive_area: Area2D = $ReviveArea

func _ready() -> void:
	add_to_group("players")
	sprite.sprite_frames = CHARACTER_FRAMES[character_index]
	sprite.play("idle")
	var passive = PASSIVES[character_index]
	max_hp = BASE_HP + passive["hp_bonus"]
	hp = max_hp
	fire_rate = BASE_FIRE_RATE * passive["fire_rate_mult"]
	aoe_mult = passive["aoe_mult"]
	heal_on_kill = passive["heal_on_kill"]

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if _revive_cooldown > 0.0:
		_revive_cooldown -= delta
	if _is_dead:
		return
	_handle_movement()
	if not is_ghost:
		_handle_auto_fire(delta)
		_check_revive_nearby()

func _handle_movement() -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_right"): dir.x += 1.0
	if Input.is_action_pressed("move_left"):  dir.x -= 1.0
	if Input.is_action_pressed("move_down"):  dir.y += 1.0
	if Input.is_action_pressed("move_up"):    dir.y -= 1.0
	var move_speed := speed * (0.4 if is_ghost else 1.0)
	velocity = dir.normalized() * move_speed
	move_and_slide()
	if dir != Vector2.ZERO:
		if not is_ghost:
			sprite.play("run")
		sprite.flip_h = dir.x < 0.0
	elif not is_ghost:
		sprite.play("idle")

func _handle_auto_fire(delta: float) -> void:
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	var target := _find_nearest_enemy()
	if target:
		_fire_timer = fire_rate
		_shoot_at.rpc(target.global_position)

func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var d := global_position.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest

@rpc("call_local")
func _shoot_at(target_pos: Vector2) -> void:
	var base_dir := (target_pos - global_position).normalized()
	var dirs: Array[Vector2] = [base_dir]
	if has_meta("scatter"):
		dirs = [
			base_dir.rotated(deg_to_rad(-20.0)),
			base_dir,
			base_dir.rotated(deg_to_rad(20.0)),
		]

	_chain_counter += 1
	var do_chain := has_meta("chain") and (_chain_counter % 5 == 0)
	var final_damage := int(20.0 * damage_mult * RunManager.get_combo_multiplier())

	for dir in dirs:
		var proj = preload("res://scenes/projectile.tscn").instantiate()
		proj.global_position = global_position
		proj.direction = dir
		proj.damage = final_damage
		proj.owner_id = player_id
		if has_meta("vampiric"):
			proj.vampiric = true
		if has_meta("phantom"):
			proj.pierce_remaining = 1
		get_tree().root.add_child(proj)

	if do_chain:
		_fire_chain_shot(final_damage)

func _fire_chain_shot(base_damage: int) -> void:
	var nearest: Node2D = null
	var nearest_dist := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var d := global_position.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	if nearest:
		var proj = preload("res://scenes/projectile.tscn").instantiate()
		proj.global_position = global_position
		proj.direction = (nearest.global_position - global_position).normalized()
		proj.damage = int(base_damage * 0.5)
		proj.owner_id = player_id
		get_tree().root.add_child(proj)

func take_damage(amount: int) -> void:
	if _is_dead or is_ghost:
		return
	hp -= amount
	RunManager.on_player_hit()
	if hp <= 0:
		_die()

func heal(amount: int) -> void:
	hp = min(hp + amount, max_hp)

func on_kill() -> void:
	if heal_on_kill > 0:
		heal(heal_on_kill)

func _die() -> void:
	_is_dead = true
	collision.set_deferred("disabled", true)
	sprite.play("death")
	await sprite.animation_finished
	is_ghost = true
	_is_dead = false
	modulate.a = 0.4
	sprite.play("idle")

# ---- Revive ----

func _check_revive_nearby() -> void:
	if _revive_cooldown > 0.0:
		return
	for body in revive_area.get_overlapping_bodies():
		if body == self or not body.is_in_group("players"):
			continue
		if body.is_ghost:
			if NetworkManager.is_solo():
				body._revive()
			else:
				body._revive.rpc_id(body.get_multiplayer_authority())
			_revive_cooldown = 1.0
			break

@rpc("any_peer", "reliable")
func _revive() -> void:
	if not is_multiplayer_authority():
		return
	is_ghost = false
	_is_dead = false
	hp = max_hp / 4
	collision.set_deferred("disabled", false)
	modulate.a = 1.0
	sprite.play("idle")
