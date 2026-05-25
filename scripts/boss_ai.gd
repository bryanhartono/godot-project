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
		var tail := _pattern_deck.slice(1)
		tail.shuffle()
		_pattern_deck = [0] + tail
	for i: int in range(1, _pattern_deck.size()):
		if _pattern_deck[i] == 2 and _pattern_deck[i - 1] == 2:
			_pattern_deck[i] = 1
	_deck_index = 0

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() and not NetworkManager.is_solo():
		return
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_advance_pattern()
	_move_toward_player()

func _move_toward_player() -> void:
	var target := _get_nearest_player()
	if not target:
		velocity = Vector2.ZERO
		return
	var dist := global_position.distance_to(target.global_position)
	if dist < 100.0:
		velocity = Vector2.ZERO
	else:
		velocity = (target.global_position - global_position).normalized() * move_speed
	move_and_slide()
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x < 0.0

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
	var target := _get_nearest_player()
	var base_dir := (target.global_position - global_position).normalized() if target else Vector2.RIGHT
	for i: int in 5:
		var angle := deg_to_rad(-40.0 + i * 20.0)
		_spawn_projectile(base_dir.rotated(angle))

func _fire_laser() -> void:
	var target := _get_nearest_player()
	if target:
		_spawn_projectile((target.global_position - global_position).normalized(), 25)

func _fire_burst() -> void:
	for i: int in 8:
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
	for p: Node in get_tree().get_nodes_in_group("players"):
		if p.is_ghost:
			continue
		var d := global_position.distance_to(p.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = p
	return nearest

func take_damage(amount: int) -> void:
	hp -= amount
	AudioManager.play("enemy_hit", -6.0)
	_flash_hit()
	if not _rage_mode and hp < max_hp * 0.4:
		_rage_mode = true
		_build_deck()
		modulate = Color(1.5, 0.5, 0.5)
		get_tree().call_group("game_world", "shake", 5.0, 0.3)
	if hp <= 0:
		_die()

func _flash_hit() -> void:
	sprite.modulate = Color(3.0, 3.0, 3.0, 1.0)
	var target_col := Color(1.5, 0.5, 0.5) if _rage_mode else Color.WHITE
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", target_col, 0.18)

func _die() -> void:
	set_physics_process(false)
	AudioManager.play("enemy_death")
	Fx.burst(global_position, Color(1.0, 0.3, 0.0, 1.0), 20, 120.0, get_parent())
	get_tree().call_group("game_world", "shake", 8.0, 0.4)
	died.emit()
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
	queue_free()
