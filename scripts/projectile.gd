extends Area2D

const SPEED = 250.0
const LIFETIME = 3.0

@export var direction: Vector2 = Vector2.RIGHT
@export var damage: int = 20
@export var is_enemy_projectile: bool = false
@export var owner_id: int = -1

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
			body.take_damage(damage)
			queue_free()
	else:
		if body.is_in_group("enemies"):
			body.take_damage(damage)
			var shooter := get_tree().get_nodes_in_group("players").filter(
				func(p): return p.player_id == owner_id
			)
			if not shooter.is_empty():
				shooter[0].on_kill()
			queue_free()
		elif body.is_in_group("boss"):
			body.take_damage(damage)
			queue_free()
