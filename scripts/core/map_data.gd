class_name MapData
extends Resource

var map_width: int = 7
var map_rows: int  = 7
var biome: StringName = &"grass"
var tiles: Dictionary = {}  # Vector2i → MapTile

func get_tile(pos: Vector2i) -> MapTile:
	return tiles.get(pos, MapTile.new())

func height_at(pos: Vector2i) -> int:
	return get_tile(pos).height

func terrain_at(pos: Vector2i) -> StringName:
	return get_tile(pos).terrain

func decoration_at(pos: Vector2i) -> StringName:
	return get_tile(pos).decoration
