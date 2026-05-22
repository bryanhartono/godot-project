extends Node2D

const FILL_CHANCE := 0.35
const AUTOMATA_PASSES := 3
const TILE_SIZE := 32

var _grid: Array = []
var _room_size: Vector2i

func generate_traps(room_rect: Rect2i, rng: RandomNumberGenerator) -> void:
	_room_size = room_rect.size
	_grid = []
	for y in _room_size.y:
		_grid.append([])
		for x in _room_size.x:
			_grid[y].append(1 if rng.randf() < FILL_CHANCE else 0)
	for _i in AUTOMATA_PASSES:
		_smooth()
	_spawn_hazards(room_rect.position)

func _smooth() -> void:
	var next: Array = []
	for y in _room_size.y:
		next.append([])
		for x in _room_size.x:
			next[y].append(1 if _neighbor_count(x, y) >= 5 else 0)
	_grid = next

func _neighbor_count(cx: int, cy: int) -> int:
	var count := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := cx + dx
			var ny := cy + dy
			if nx < 0 or ny < 0 or nx >= _room_size.x or ny >= _room_size.y:
				count += 1
			else:
				count += _grid[ny][nx]
	return count

func _spawn_hazards(origin: Vector2i) -> void:
	for y in _room_size.y:
		for x in _room_size.x:
			if _grid[y][x] == 1:
				var hazard := ColorRect.new()
				hazard.size = Vector2(TILE_SIZE, TILE_SIZE)
				hazard.position = Vector2((origin.x + x) * TILE_SIZE, (origin.y + y) * TILE_SIZE)
				hazard.color = Color(1.0, 0.2, 0.2, 0.35)
				add_child(hazard)
