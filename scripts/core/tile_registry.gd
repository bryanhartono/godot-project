class_name TileRegistry

const TEXTURE_PATH := "res://assets/Sprites/Tiles.png"

# Flat ground tile (height 0) — 16x16 region.
# Row 2 of the sheet (y=32). Identified by color analysis:
#   C0 (145,134,141) gray     → stone
#   C1 (184,205,225) blue-wht → snow
#   C2 (202,100, 45) orange-r → lava
#   C3 (118, 99, 60) brown    → dirt/desert-brown
#   C4 (131,187, 43) bright G → grass
#   C10(130,170,205) blue-gry → water
static var FLAT: Dictionary = {
	&"grass":  Rect2i( 64, 32, 16, 16),  # R2 C4 — bright green (131,187,43)
	&"stone":  Rect2i(  0, 32, 16, 16),  # R2 C0 — gray (145,134,141)
	&"snow":   Rect2i( 16, 32, 16, 16),  # R2 C1 — light blue-white (184,205,225)
	&"desert": Rect2i( 48, 32, 16, 16),  # R2 C3 — sandy brown (118,99,60)
	&"water":  Rect2i(160, 32, 16, 16),  # R2 C10 — blue-gray (130,170,205)
	&"lava":   Rect2i( 32, 32, 16, 16),  # R2 C2 — orange-red (202,100,45)
}

# Elevated cube tile (height 1) — 16x32 region spanning rows 0-1.
# Top 16px (row 0) = isometric diamond top face.
# Bottom 16px (row 1) = front wall face.
# Identified by color analysis:
#   C1 R0=(99,99,59) R1=(75,96,63)     olive green  → grass
#   C2 R0=(91,82,111) R1=(89,77,109)   purple-gray  → stone
#   C3 R0=(227,164,115) R1=(231,154,106) orange-tan → desert
#   C5 R0=(96,223,235) R1=(114,229,239) bright cyan → snow/ice
static var CUBE: Dictionary = {
	&"grass":  Rect2i( 16, 0, 16, 16),  # R0 C1 — olive green cube (16×16, rendered at 4×4 scale = 64×64)
	&"stone":  Rect2i( 32, 0, 16, 16),  # R0 C2 — purple-gray cube
	&"desert": Rect2i( 48, 0, 16, 16),  # R0 C3 — orange-tan cube
	&"snow":   Rect2i( 80, 0, 16, 16),  # R0 C5 — bright cyan cube
}

# Wall extender — 16x16, drawn below cube sprite for height-2+ tiles.
# Rows 4-7 are all uniform brown dirt fill (~114,92,66). Use R4 C0.
static var WALL_EXTENDER: Rect2i = Rect2i(0, 64, 16, 16)  # R4 C0

# Decoration sprites — 16x16.
# Rows 8-9 contain small decoration objects. Colors noted per cell:
#   C0 (138,116,84)  warm brown  → dirt patch / plain ground
#   C1 (101,108,118) blue-gray   → rock / stone boulder
#   C2 (145, 72, 51) red-brown   → red mushroom / lava rock — VERIFY
#   C3 (114, 86, 47) dark brown  → tree stump / rock — VERIFY
#   C4 (117, 93, 78) brown       → small rock — VERIFY
#   C5 ( 98, 87, 99) purple-gray → crystal / gem — VERIFY
#   C6 ( 99, 70, 54) dark brown  → fence post — VERIFY
#   C7 (130,105, 80) tan         → fence segment — VERIFY
#   C8 (148,122,111) pinkish     → flower / shrub — VERIFY
static var DECORATION: Dictionary = {
	&"rock":    Rect2i( 16, 128, 16, 16),  # R8 C1 — blue-gray (101,108,118)
	&"tree":    Rect2i(  0, 128, 16, 16),  # R8 C0 — warm brown; VERIFY (may be plain)
	&"fence":   Rect2i( 96, 128, 16, 16),  # R8 C6 — dark brown post; VERIFY
	&"flower":  Rect2i(128, 128, 16, 16),  # R8 C8 — pinkish (148,122,111); VERIFY
	&"crystal": Rect2i( 80, 128, 16, 16),  # R8 C5 — purple-gray (98,87,99); VERIFY
}

static func flat_region(biome: StringName) -> Rect2i:
	return FLAT.get(biome, FLAT[&"grass"])

static func cube_region(biome: StringName) -> Rect2i:
	return CUBE.get(biome, CUBE[&"grass"])

static func decoration_region(dec: StringName) -> Rect2i:
	return DECORATION.get(dec, Rect2i())
