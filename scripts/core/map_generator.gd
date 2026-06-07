class_name MapGenerator

const BIOMES:  Array[StringName] = [&"grass", &"stone", &"snow", &"desert"]
const MIN_SIZE := 7
const MAX_SIZE := 10
const WATER_LAVA_DENSITY := 0.15
const DECORATION_DENSITIES := {
	&"rock":   0.10,
	&"tree":   0.12,
	&"fence":  0.05,
	&"flower": 0.15,
}
const TREE_BIOMES:   Array[StringName] = [&"grass", &"snow"]
const FLOWER_BIOMES: Array[StringName] = [&"grass", &"snow"]
const MAX_RETRIES := 10

static func generate(seed: int = -1) -> MapData:
	if seed < 0:
		seed = randi()
	for attempt in MAX_RETRIES:
		var md := _attempt(seed + attempt)
		if _validate(md):
			return md
	return _flat_fallback(seed)

static func _attempt(seed: int) -> MapData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var md         := MapData.new()
	md.biome       = BIOMES[rng.randi() % BIOMES.size()]
	md.map_width   = MIN_SIZE + rng.randi() % (MAX_SIZE - MIN_SIZE + 1)
	md.map_rows    = MIN_SIZE + rng.randi() % (MAX_SIZE - MIN_SIZE + 1)

	# Height noise
	var hn := FastNoiseLite.new()
	hn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	hn.frequency  = 0.35
	hn.seed       = seed

	# Water/lava placement noise
	var wn := FastNoiseLite.new()
	wn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wn.frequency  = 0.5
	wn.seed       = seed + 1000

	var water_terrain: StringName = &"water" if md.biome in [&"grass", &"snow"] else &"lava"

	# Build tiles
	for y in md.map_rows:
		for x in md.map_width:
			var pos   := Vector2i(x, y)
			var t     := MapTile.new()
			t.terrain  = md.biome

			var raw: float = (hn.get_noise_2d(x, y) + 1.0) * 0.5  # normalise [0,1]
			if   raw < 0.35: t.height = 0
			elif raw < 0.70: t.height = 1
			else:            t.height = 2

			# Water/lava on height-0 tiles only
			if t.height == 0:
				var wraw: float = (wn.get_noise_2d(x, y) + 1.0) * 0.5
				if wraw < WATER_LAVA_DENSITY:
					t.terrain = water_terrain

			md.tiles[pos] = t

	# Protect deploy zones
	for y in [0, 1, md.map_rows - 2, md.map_rows - 1]:
		for x in md.map_width:
			var t: MapTile = md.tiles[Vector2i(x, y)]
			t.height      = 0
			t.terrain     = md.biome
			t.decoration  = &"none"

	# Scatter decorations on walkable tiles (skip deploy zones)
	var protected_ys: Array[int] = [0, 1, md.map_rows - 2, md.map_rows - 1]
	for y in md.map_rows:
		if y in protected_ys:
			continue
		for x in md.map_width:
			var pos := Vector2i(x, y)
			var t: MapTile = md.tiles[pos]
			if t.terrain in [&"water", &"lava"]:
				continue
			t.decoration = _pick_decoration(rng, t, md.biome)

	return md

static func _pick_decoration(rng: RandomNumberGenerator, t: MapTile, biome: StringName) -> StringName:
	if t.height in [1, 2] and rng.randf() < DECORATION_DENSITIES[&"rock"]:
		return &"rock"
	if t.height in [0, 1] and biome in TREE_BIOMES and rng.randf() < DECORATION_DENSITIES[&"tree"]:
		return &"tree"
	if t.height in [0, 1] and rng.randf() < DECORATION_DENSITIES[&"fence"]:
		return &"fence"
	if t.height == 0 and biome in FLOWER_BIOMES and rng.randf() < DECORATION_DENSITIES[&"flower"]:
		return &"flower"
	return &"none"

static func _validate(md: MapData) -> bool:
	var walkable: Array[Vector2i] = []
	for pos: Vector2i in md.tiles:
		var t: MapTile = md.tiles[pos]
		if t.terrain not in [&"water", &"lava"] and t.decoration not in [&"rock", &"tree", &"fence"]:
			walkable.append(pos)
	if walkable.is_empty():
		return false
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [walkable[0]]
	visited[walkable[0]] = true
	var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	while queue.size() > 0:
		var cur: Vector2i = queue.pop_front()
		for d in dirs:
			var nb: Vector2i = cur + d
			if visited.has(nb): continue
			if not md.tiles.has(nb): continue
			var t2: MapTile = md.tiles[nb]
			if t2.terrain in [&"water", &"lava"]: continue
			if t2.decoration in [&"rock", &"tree", &"fence"]: continue
			visited[nb] = true
			queue.append(nb)
	return float(visited.size()) / float(walkable.size()) >= 0.60

static func _flat_fallback(seed: int) -> MapData:
	var rng  := RandomNumberGenerator.new()
	rng.seed  = seed
	var md   := MapData.new()
	md.biome  = BIOMES[rng.randi() % BIOMES.size()]
	md.map_width = 7
	md.map_rows  = 7
	for y in 7:
		for x in 7:
			var t     := MapTile.new()
			t.terrain  = md.biome
			md.tiles[Vector2i(x, y)] = t
	return md
