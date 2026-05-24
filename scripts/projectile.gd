extends Area2D

const SPEED = 250.0
const LIFETIME = 3.0

@export var direction: Vector2 = Vector2.RIGHT
@export var damage: int = 20
@export var is_enemy_projectile: bool = false
@export var owner_id: int = -1
@export var vampiric: bool = false
@export var pierce_remaining: int = 0

var _time_alive: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("fly"):
		sprite.play("fly")
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	position += direction * SPEED * delta
	_time_alive += delta
	if _time_alive >= LIFETIME:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if is_enemy_projectile:
		if body.is_in_group("players"):
			Fx.burst(global_position, Color(1.0, 0.22, 0.1, 1.0), 5, 45.0, get_parent())
			body.take_damage(damage)
			queue_free()
		return

	var hit_damageable := body.is_in_group("enemies") or body.is_in_group("boss")
	if not hit_damageable:
		return

	body.take_damage(damage)

	if vampiric:
		_apply_to_owner(func(p: Node) -> void: p.heal(int(damage * 0.1)))

	if body.is_in_group("enemies"):
		_apply_to_owner(func(p: Node) -> void: p.on_kill())

	if pierce_remaining > 0:
		pierce_remaining -= 1
	else:
		Fx.burst(global_position, Color(0.85, 0.95, 1.0, 1.0), 5, 50.0, get_parent())
		queue_free()

func _apply_to_owner(fn: Callable) -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if p.player_id == owner_id:
			fn.call(p)
			break
