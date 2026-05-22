extends Node2D

const FILL_CHANCE: float = 0.35
const AUTOMATA_PASSES: int = 3

var _grid: Array[Array] = []
var _room_size: Vector2i

@onready var tilemap: TileMapLayer = $TileMapLayer

func generate_traps(room_rect: Rect2i, rng: RandomNumberGenerator) -> void:
	DungeonPainter.paint_room(tilemap, room_rect)

	_room_size = room_rect.size
	_grid = []
	for y: int in _room_size.y:
		var row: Array[int] = []
		for x: int in _room_size.x:
			row.append(1 if rng.randf() < FILL_CHANCE else 0)
		_grid.append(row)
	for _i: int in AUTOMATA_PASSES:
		_smooth()
	_spawn_hazards(room_rect)

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

func _spawn_hazards(rect: Rect2i) -> void:
	var offset := Vector2(
		-(rect.position.x + rect.size.x / 2.0),
		-(rect.position.y + rect.size.y / 2.0)
	)
	var px := float(DungeonPainter.TILE_PX)
	# Inset by 1 tile to stay inside walls
	for y: int in range(1, _room_size.y - 1):
		for x: int in range(1, _room_size.x - 1):
			if _grid[y][x] == 1:
				var hazard := ColorRect.new()
				hazard.size = Vector2(px, px)
				var wx: float = (rect.position.x + x + offset.x) * px
				var wy: float = (rect.position.y + y + offset.y) * px
				hazard.position = Vector2(wx, wy)
				hazard.color = Color(1.0, 0.2, 0.2, 0.35)
				add_child(hazard)
