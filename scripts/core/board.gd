class_name Board
extends RefCounted

## The grid and unit occupancy. Vector2i positions are keys into _occupancy.

var width: int = 7
var height: int = 7
var _occupancy: Dictionary = {}  # Vector2i -> BattleUnit

func _init(p_width: int = 7, p_height: int = 7) -> void:
	width = p_width
	height = p_height

func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func is_occupied(pos: Vector2i) -> bool:
	return _occupancy.has(pos)

func get_unit_at(pos: Vector2i) -> BattleUnit:
	return _occupancy.get(pos, null)

func place_unit(unit: BattleUnit, pos: Vector2i) -> void:
	_occupancy[pos] = unit
	unit.grid_pos = pos

func relocate_unit(unit: BattleUnit, pos: Vector2i) -> void:
	_occupancy.erase(unit.grid_pos)
	_occupancy[pos] = unit
	unit.grid_pos = pos

func remove_unit(unit: BattleUnit) -> void:
	_occupancy.erase(unit.grid_pos)
