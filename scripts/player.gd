extends CharacterBody2D

const BASE_HP = 100
const BASE_FIRE_RATE = 0.5
const SPEED = 120.0

@export var player_id: int = 1
@export var character_index: int = 0  # 0=Blue 1=Red 2=Green 3=Grey

# Per-character passives: fire_rate_mult, aoe_mult, heal_on_kill, hp_bonus
const PASSIVES = [
	{"fire_rate_mult": 0.7, "aoe_mult": 1.0, "heal_on_kill": 0,  "hp_bonus": 0},
	{"fire_rate_mult": 1.0, "aoe_mult": 1.5, "heal_on_kill": 0,  "hp_bonus": 0},
	{"fire_rate_mult": 1.0, "aoe_mult": 1.0, "heal_on_kill": 5,  "hp_bonus": 0},
	{"fire_rate_mult": 1.0, "aoe_mult": 1.0, "heal_on_kill": 0,  "hp_bonus": 50},
]

var max_hp: int = BASE_HP
var hp: int = BASE_HP
var fire_rate: float = BASE_FIRE_RATE
var aoe_mult: float = 1.0
var heal_on_kill: int = 0
var owned_upgrade_tags: Array = []

var _fire_timer: float = 0.0
var _is_dead: bool = false
var _is_ghost: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("players")
	var passive = PASSIVES[character_index]
	max_hp = BASE_HP + passive["hp_bonus"]
	hp = max_hp
	fire_rate = BASE_FIRE_RATE * passive["fire_rate_mult"]
	aoe_mult = passive["aoe_mult"]
	heal_on_kill = passive["heal_on_kill"]

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if _is_dead:
		return
	_handle_movement()
	_handle_auto_fire(delta)

func _handle_movement() -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_right"): dir.x += 1.0
	if Input.is_action_pressed("move_left"):  dir.x -= 1.0
	if Input.is_action_pressed("move_down"):  dir.y += 1.0
	if Input.is_action_pressed("move_up"):    dir.y -= 1.0
	velocity = dir.normalized() * SPEED
	move_and_slide()
	if dir != Vector2.ZERO:
		sprite.play("run")
		sprite.flip_h = dir.x < 0.0
	else:
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
	var proj = preload("res://scenes/projectile.tscn").instantiate()
	proj.global_position = global_position
	proj.direction = (target_pos - global_position).normalized()
	proj.owner_id = player_id
	get_tree().root.add_child(proj)

func take_damage(amount: int) -> void:
	if _is_dead or _is_ghost:
		return
	hp -= amount
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
	_is_ghost = true
	_is_dead = false
	modulate.a = 0.4
