extends Control

const W := 150.0
const H := 110.0

const _COLORS := {
	"start":      Color(0.3,  0.9,  0.4,  1.0),
	"combat":     Color(0.75, 0.25, 0.2,  1.0),
	"shop":       Color(0.2,  0.65, 1.0,  1.0),
	"treasure":   Color(1.0,  0.85, 0.1,  1.0),
	"trap":       Color(0.9,  0.5,  0.15, 1.0),
	"boss_entry": Color(0.85, 0.1,  0.85, 1.0),
}

var _rooms: Array[Dictionary] = []
var _player_pos: Vector2 = Vector2.ZERO
var _world_bounds: Rect2 = Rect2()

func setup(tagged_rooms: Array[Dictionary], map_size: Vector2i) -> void:
	_rooms.clear()
	var half := Vector2(map_size) * DungeonPainter.TILE_PX * 0.5
	_world_bounds = Rect2(-half, half * 2.0)
	for r: Dictionary in tagged_rooms:
		var wr := DungeonPainter.get_room_world_rect(r["rect"], map_size)
		_rooms.append({"wr": wr, "type": r["type"], "visited": false})
	if not _rooms.is_empty():
		_rooms[0]["visited"] = true
	size = Vector2(W, H)
	queue_redraw()

func mark_visited(index: int) -> void:
	if index < _rooms.size():
		_rooms[index]["visited"] = true
		queue_redraw()

func set_player_pos(world_pos: Vector2) -> void:
	_player_pos = world_pos
	queue_redraw()

func _to_mm(p: Vector2) -> Vector2:
	return (p - _world_bounds.position) / _world_bounds.size * Vector2(W, H)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.04, 0.06, 0.12, 0.88))
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.0, 0.6, 0.8, 0.7), false, 1.5)
	for r: Dictionary in _rooms:
		var col: Color = _COLORS.get(r["type"], Color(0.5, 0.5, 0.5)) if r["visited"] \
			else Color(0.15, 0.17, 0.22, 0.9)
		var tl := _to_mm(r["wr"].position)
		var br := _to_mm(r["wr"].end)
		var rr := Rect2(tl, br - tl)
		draw_rect(rr, col)
		draw_rect(rr, Color(0.0, 0.0, 0.0, 0.5), false, 0.5)
	draw_circle(_to_mm(_player_pos), 3.0, Color(1.0, 1.0, 0.3))
