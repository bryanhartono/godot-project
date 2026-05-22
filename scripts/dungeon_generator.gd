class_name DungeonGenerator
extends RefCounted

const MIN_ROOM = Vector2i(6, 5)
const MAX_ROOM = Vector2i(14, 10)
const MAP_SIZE = Vector2i(60, 40)

class BSPNode:
	var rect: Rect2i
	var left: BSPNode
	var right: BSPNode
	var room: Rect2i

	func _init(r: Rect2i) -> void:
		rect = r

var rooms: Array = []
var corridors: Array = []
var rng: RandomNumberGenerator

func generate(seed_value: int) -> Dictionary:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	rooms.clear()
	corridors.clear()
	var root := BSPNode.new(Rect2i(0, 0, MAP_SIZE.x, MAP_SIZE.y))
	_split(root, 4)
	_place_rooms(root)
	_connect_rooms(root)
	return {"rooms": rooms, "corridors": corridors}

func tag_rooms(floor_number: int) -> Array:
	var tags := ["combat", "combat", "combat", "treasure", "shop", "trap"]
	var result: Array = []
	for i in rooms.size():
		var tag := "combat"
		if i == rooms.size() - 1 and floor_number % 5 == 0:
			tag = "boss_entry"
		elif i < tags.size():
			tag = tags[i]
		result.append({"rect": rooms[i], "type": tag})
	return result

func _split(node: BSPNode, depth: int) -> void:
	if depth == 0:
		return
	if node.rect.size.x < MIN_ROOM.x * 2 and node.rect.size.y < MIN_ROOM.y * 2:
		return
	var horiz := rng.randf() > 0.5
	if node.rect.size.x > node.rect.size.y * 1.25:
		horiz = false
	elif node.rect.size.y > node.rect.size.x * 1.25:
		horiz = true

	if horiz:
		var min_split := MIN_ROOM.y
		var max_split := node.rect.size.y - MIN_ROOM.y
		if min_split >= max_split:
			return
		var split := rng.randi_range(min_split, max_split)
		node.left = BSPNode.new(Rect2i(node.rect.position, Vector2i(node.rect.size.x, split)))
		node.right = BSPNode.new(Rect2i(node.rect.position + Vector2i(0, split), Vector2i(node.rect.size.x, node.rect.size.y - split)))
	else:
		var min_split := MIN_ROOM.x
		var max_split := node.rect.size.x - MIN_ROOM.x
		if min_split >= max_split:
			return
		var split := rng.randi_range(min_split, max_split)
		node.left = BSPNode.new(Rect2i(node.rect.position, Vector2i(split, node.rect.size.y)))
		node.right = BSPNode.new(Rect2i(node.rect.position + Vector2i(split, 0), Vector2i(node.rect.size.x - split, node.rect.size.y)))

	_split(node.left, depth - 1)
	_split(node.right, depth - 1)

func _place_rooms(node: BSPNode) -> void:
	if node.left == null and node.right == null:
		var w := rng.randi_range(MIN_ROOM.x, min(MAX_ROOM.x, node.rect.size.x - 2))
		var h := rng.randi_range(MIN_ROOM.y, min(MAX_ROOM.y, node.rect.size.y - 2))
		var x := node.rect.position.x + rng.randi_range(1, max(1, node.rect.size.x - w - 1))
		var y := node.rect.position.y + rng.randi_range(1, max(1, node.rect.size.y - h - 1))
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
	var a := _center(node.left.room)
	var b := _center(node.right.room)
	if rng.randf() > 0.5:
		corridors.append(Rect2i(min(a.x, b.x), a.y, abs(b.x - a.x) + 1, 1))
		corridors.append(Rect2i(b.x, min(a.y, b.y), 1, abs(b.y - a.y) + 1))
	else:
		corridors.append(Rect2i(a.x, min(a.y, b.y), 1, abs(b.y - a.y) + 1))
		corridors.append(Rect2i(min(a.x, b.x), b.y, abs(b.x - a.x) + 1, 1))

func _center(room: Rect2i) -> Vector2i:
	return room.position + room.size / 2
