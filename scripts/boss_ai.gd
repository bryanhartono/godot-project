extends CharacterBody2D

signal died()
signal phase_changed(phase: int)

@export var base_hp: int = 500
@export var move_speed: float = 40.0

var max_hp: int
var hp: int
var _pattern_deck: Array[int] = []
var _deck_index: int = 0
var _current_phase: int = 0
var _rage_mode: bool = false
var _shoot_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("boss")
	max_hp = int(base_hp * RunManager.get_boss_hp_multiplier())
	hp = max_hp
	_build_deck()
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")

func _build_deck() -> void:
	_pattern_deck = [0, 0, 1, 2, 1]
	if _rage_mode:
		_pattern_deck.shuffle()
		_pattern_deck.push_front(0)
	else:
		var tail = _pattern_deck.slice(1)
		tail.shuffle()
		_pattern_deck = [0] + tail
	# Prevent phase 2 appearing back-to-back
	for i in range(1, _pattern_deck.size()):
		if _pattern_deck[i] == 2 and _pattern_deck[i - 1] == 2:
			_pattern_deck[i] = 1
	_deck_index = 0

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() and not NetworkManager.is_solo():
		return
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_advance_pattern()

func _advance_pattern() -> void:
	_current_phase = _pattern_deck[_deck_index]
	_deck_index = (_deck_index + 1) % _pattern_deck.size()
	phase_changed.emit(_current_phase)
	_execute_phase(_current_phase)

func _execute_phase(phase: int) -> void:
	match phase:
		0:
			_shoot_timer = 2.0
			if sprite.sprite_frames and sprite.sprite_frames.has_animation("shoot"):
				sprite.play("shoot")
			_fire_spread()
		1:
			_shoot_timer = 3.0
			if sprite.sprite_frames and sprite.sprite_frames.has_animation("shoot_2"):
				sprite.play("shoot_2")
			_fire_laser()
		2:
			_shoot_timer = 4.0
			if sprite.sprite_frames and sprite.sprite_frames.has_animation("shoot_3"):
				sprite.play("shoot_3")
			_fire_burst()

func _fire_spread() -> void:
	for i in 5:
		var angle := deg_to_rad(-40.0 + i * 20.0)
		_spawn_projectile(Vector2.RIGHT.rotated(angle))

func _fire_laser() -> void:
	var target := _get_nearest_player()
	if target:
		_spawn_projectile((target.global_position - global_position).normalized(), 25)

func _fire_burst() -> void:
	for i in 8:
		_spawn_projectile(Vector2.RIGHT.rotated(deg_to_rad(i * 45.0)))

func _spawn_projectile(dir: Vector2, damage: int = 15) -> void:
	var proj = preload("res://scenes/projectile.tscn").instantiate()
	proj.global_position = global_position
	proj.direction = dir
	proj.damage = damage
	proj.is_enemy_projectile = true
	get_tree().root.add_child(proj)

func _get_nearest_player() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := INF
	for p in get_tree().get_nodes_in_group("players"):
		var d := global_position.distance_to(p.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = p
	return nearest

func take_damage(amount: int) -> void:
	hp -= amount
	if not _rage_mode and hp < max_hp * 0.4:
		_rage_mode = true
		_build_deck()
		modulate = Color(1.5, 0.5, 0.5)
	if hp <= 0:
		_die()

func _die() -> void:
	set_physics_process(false)
	died.emit()
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
	queue_free()
