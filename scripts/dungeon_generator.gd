class_name DungeonGenerator
extends RefCounted

const MIN_ROOM: Vector2i = Vector2i(8, 6)
const MAX_ROOM: Vector2i = Vector2i(14, 10)

class BSPNode:
	var rect: Rect2i
	var left: BSPNode
	var right: BSPNode
	var room: Rect2i

	func _init(r: Rect2i) -> void:
		rect = r

var rooms: Array[Rect2i] = []
var corridors: Array[Rect2i] = []
var rng: RandomNumberGenerator

func generate(seed_value: int, floor_number: int = 1) -> Dictionary:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	rooms.clear()
	corridors.clear()
	var map_size: Vector2i
	var split_depth: int
	if floor_number <= 2:
		map_size = Vector2i(40, 30)
		split_depth = 3
	elif floor_number <= 4:
		map_size = Vector2i(50, 37)
		split_depth = 4
	else:
		map_size = Vector2i(60, 44)
		split_depth = 4
	var root := BSPNode.new(Rect2i(0, 0, map_size.x, map_size.y))
	_split(root, split_depth)
	_place_rooms(root)
	_connect_rooms(root)
	return {"rooms": rooms, "corridors": corridors, "map_size": map_size}

func tag_rooms(floor_number: int) -> Array[Dictionary]:
	var pattern: Array[String]
	if floor_number % 5 == 0:
		pattern = ["start", "combat", "combat", "shop", "combat", "trap", "combat", "treasure", "boss_entry"]
	elif floor_number % 3 == 0:
		pattern = ["start", "trap", "combat", "combat", "shop", "combat", "treasure", "combat", "combat", "combat"]
	elif floor_number % 2 == 0:
		pattern = ["start", "combat", "trap", "combat", "treasure", "combat", "shop", "combat", "combat"]
	else:
		pattern = ["start", "combat", "shop", "combat", "trap", "treasure", "combat", "combat"]

	var result: Array[Dictionary] = []
	for i: int in rooms.size():
		var tag: String = pattern[i] if i < pattern.size() else "combat"
		result.append({"rect": rooms[i], "type": tag})
	return result

func _split(node: BSPNode, depth: int) -> void:
	if depth == 0:
		return
	if node.rect.size.x < MIN_ROOM.x * 2 + 2 and node.rect.size.y < MIN_ROOM.y * 2 + 2:
		return
	var horiz: bool = rng.randf() > 0.5
	if node.rect.size.x > node.rect.size.y * 1.25:
		horiz = false
	elif node.rect.size.y > node.rect.size.x * 1.25:
		horiz = true

	if horiz:
		var min_split: int = MIN_ROOM.y + 1
		var max_split: int = node.rect.size.y - MIN_ROOM.y - 1
		if min_split >= max_split:
			return
		var split: int = rng.randi_range(min_split, max_split)
		node.left = BSPNode.new(Rect2i(node.rect.position, Vector2i(node.rect.size.x, split)))
		node.right = BSPNode.new(Rect2i(node.rect.position + Vector2i(0, split), Vector2i(node.rect.size.x, node.rect.size.y - split)))
	else:
		var min_split: int = MIN_ROOM.x + 1
		var max_split: int = node.rect.size.x - MIN_ROOM.x - 1
		if min_split >= max_split:
			return
		var split: int = rng.randi_range(min_split, max_split)
		node.left = BSPNode.new(Rect2i(node.rect.position, Vector2i(split, node.rect.size.y)))
		node.right = BSPNode.new(Rect2i(node.rect.position + Vector2i(split, 0), Vector2i(node.rect.size.x - split, node.rect.size.y)))

	_split(node.left, depth - 1)
	_split(node.right, depth - 1)

func _place_rooms(node: BSPNode) -> void:
	if node.left == null and node.right == null:
		var w: int = rng.randi_range(MIN_ROOM.x, min(MAX_ROOM.x, node.rect.size.x - 2))
		var h: int = rng.randi_range(MIN_ROOM.y, min(MAX_ROOM.y, node.rect.size.y - 2))
		var x: int = node.rect.position.x + rng.randi_range(1, max(1, node.rect.size.x - w - 1))
		var y: int = node.rect.position.y + rng.randi_range(1, max(1, node.rect.size.y - h - 1))
		node.room = Rect2i(x, y, w, h)
		rooms.append(node.room)
		return
	if node.left:
		_place_rooms(node.left)
	if node.right:
		_place_rooms(node.right)
	if node.left and node.right:
		node.room = node.left.room if rng.randf() > 0.5 else node.right.room

func _connect_rooms(node: BSPNode) -> void:
	if node.left == null or node.right == null:
		return
	_connect_rooms(node.left)
	_connect_rooms(node.right)
	var a: Vector2i = _center(node.left.room)
	var b: Vector2i = _center(node.right.room)
	if rng.randf() > 0.5:
		corridors.append(Rect2i(min(a.x, b.x), a.y, abs(b.x - a.x) + 1, 1))
		corridors.append(Rect2i(b.x, min(a.y, b.y), 1, abs(b.y - a.y) + 1))
	else:
		corridors.append(Rect2i(a.x, min(a.y, b.y), 1, abs(b.y - a.y) + 1))
		corridors.append(Rect2i(min(a.x, b.x), b.y, abs(b.x - a.x) + 1, 1))

func _center(room: Rect2i) -> Vector2i:
	return room.position + Vector2i(room.size.x >> 1, room.size.y >> 1)
