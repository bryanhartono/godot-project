extends Node2D

const FILL_CHANCE: float = 0.35
const AUTOMATA_PASSES: int = 3
const TILE_SIZE: int = 32

var _grid: Array[Array] = []
var _room_size: Vector2i

func generate_traps(room_rect: Rect2i, rng: RandomNumberGenerator) -> void:
	_room_size = room_rect.size
	_grid = []
	for y: int in _room_size.y:
		var row: Array[int] = []
		for x: int in _room_size.x:
			row.append(1 if rng.randf() < FILL_CHANCE else 0)
		_grid.append(row)
	for _i: int in AUTOMATA_PASSES:
		_smooth()
	_spawn_hazards(room_rect.position)

func _smooth() -> void:
	var next: Array[Array] = []
	for y: int in _room_size.y:
		var row: Array[int] = []
		for x: int in _room_size.x:
			row.append(1 if _neighbor_count(x, y) >= 5 else 0)
		next.append(row)
	_grid = next

func _neighbor_count(cx: int, cy: int) -> int:
	var count: int = 0
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = cx + dx
			var ny: int = cy + dy
			if nx < 0 or ny < 0 or nx >= _room_size.x or ny >= _room_size.y:
				count += 1
			else:
				count += _grid[ny][nx]
	return count

func _spawn_hazards(origin: Vector2i) -> void:
	for y: int in _room_size.y:
		for x: int in _room_size.x:
			if _grid[y][x] == 1:
				var hazard := ColorRect.new()
				hazard.size = Vector2(TILE_SIZE, TILE_SIZE)
				hazard.position = Vector2((origin.x + x) * TILE_SIZE, (origin.y + y) * TILE_SIZE)
				hazard.color = Color(1.0, 0.2, 0.2, 0.35)
				add_child(hazard)
