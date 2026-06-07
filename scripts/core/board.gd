class_name Board
extends RefCounted

var width: int = 7
var height: int = 7
var _occupancy:  Dictionary = {}  # Vector2i → BattleUnit
var _elevation:  Dictionary = {}  # Vector2i → int
var _terrain:    Dictionary = {}  # Vector2i → StringName
var _decoration: Dictionary = {}  # Vector2i → StringName

func _init(p_width: int = 7, p_height: int = 7) -> void:
    width  = p_width
    height = p_height

func load_map(map: MapData) -> void:
    width  = map.map_width
    height = map.map_rows
    _elevation.clear()
    _terrain.clear()
    _decoration.clear()
    for pos: Vector2i in map.tiles:
        var t: MapTile = map.tiles[pos]
        _elevation[pos]  = t.height
        _terrain[pos]    = t.terrain
        _decoration[pos] = t.decoration

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

func elevation_at(pos: Vector2i) -> int:
    return _elevation.get(pos, 0)

func is_passable(pos: Vector2i, movement_type: StringName = &"ground") -> bool:
    if not is_in_bounds(pos):
        return false
    var t: StringName = _terrain.get(pos, &"grass")
    var d: StringName = _decoration.get(pos, &"none")
    match t:
        &"water":
            if movement_type not in [&"flying", &"water"]:
                return false
        &"lava":
            if movement_type not in [&"flying", &"lava"]:
                return false
    if d in [&"rock", &"tree", &"fence"]:
        if movement_type != &"flying":
            return false
    return true
