extends CharacterBody2D

signal died(enemy: Node)

enum State { SPAWN, IDLE, MOVE, SHOOT, DEAD }

@export var max_hp: int = 30
@export var move_speed: float = 60.0
@export var budget_cost: int = 3
@export var shoot_range: float = 200.0
@export var shoot_cooldown: float = 2.0
@export var projectile_damage: int = 10
@export var elite_modifier: String = ""

var hp: int
var state: State = State.SPAWN
var _shoot_timer: float = 0.0
var _target: Node2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	_apply_elite()
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("spawn_idle"):
		sprite.play("spawn_idle")
		await sprite.animation_finished
	state = State.IDLE

func _apply_elite() -> void:
	match elite_modifier:
		"speedy":   move_speed *= 1.5
		"armored":  max_hp = int(max_hp * 1.5); hp = max_hp
	if elite_modifier != "":
		modulate = Color(1.3, 0.8, 0.3)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() and not NetworkManager.is_solo():
		return
	match state:
		State.IDLE:  _tick_idle()
		State.MOVE:  _tick_move()
		State.SHOOT: _tick_shoot(delta)

func _tick_idle() -> void:
	_target = _find_nearest_player()
	if _target:
		state = State.MOVE

func _tick_move() -> void:
	if not is_instance_valid(_target):
		state = State.IDLE
		return
	var dist := global_position.distance_to(_target.global_position)
	if dist <= shoot_range:
		state = State.SHOOT
		velocity = Vector2.ZERO
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle_2"):
			sprite.play("idle_2")
		return
	var dir := (_target.global_position - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("run"):
		sprite.play("run")
	sprite.flip_h = velocity.x < 0.0

func _tick_shoot(delta: float) -> void:
	if not is_instance_valid(_target):
		state = State.IDLE
		return
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_timer = shoot_cooldown
		_fire()
	if global_position.distance_to(_target.global_position) > shoot_range * 1.2:
		state = State.MOVE

func _fire() -> void:
	var proj = preload("res://scenes/projectile.tscn").instantiate()
	proj.global_position = global_position
	proj.direction = (_target.global_position - global_position).normalized()
	proj.damage = projectile_damage
	proj.is_enemy_projectile = true
	get_tree().root.add_child(proj)

func _find_nearest_player() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for p in get_tree().get_nodes_in_group("players"):
		var d := global_position.distance_to(p.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = p
	return nearest

func take_damage(amount: int, from_front: bool = false) -> void:
	if state == State.DEAD:
		return
	var effective = amount / 2 if elite_modifier == "shielded" and from_front else amount
	hp -= effective
	if hp <= 0:
		_die()

func _die() -> void:
	state = State.DEAD
	set_physics_process(false)
	died.emit(self)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
	if elite_modifier == "exploder":
		_spawn_splits()
	queue_free()

func _spawn_splits() -> void:
	for i in 2:
		var e = preload("res://scenes/enemy.tscn").instantiate()
		e.max_hp = 8
		e.budget_cost = 1
		e.global_position = global_position + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
		get_parent().add_child(e)
