extends Area2D

const DAMAGE_PER_SECOND := 8.0
const TICK := 0.4

var _inside: Array = []
var _timer: float = TICK

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() and not NetworkManager.is_solo():
		return
	if _inside.is_empty():
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = TICK
		for p: Node in _inside:
			if is_instance_valid(p) and not p.is_ghost:
				p.take_damage(int(DAMAGE_PER_SECOND * TICK))

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		_inside.append(body)

func _on_body_exited(body: Node2D) -> void:
	_inside.erase(body)
