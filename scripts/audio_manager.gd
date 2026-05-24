extends Node

const POOL_SIZE := 8

const _SHOOT: Array = [
	preload("res://assets/Audio/SFX/kenney_interface-sounds/Audio/glitch_001.ogg"),
	preload("res://assets/Audio/SFX/kenney_interface-sounds/Audio/glitch_002.ogg"),
	preload("res://assets/Audio/SFX/kenney_interface-sounds/Audio/glitch_003.ogg"),
	preload("res://assets/Audio/SFX/kenney_interface-sounds/Audio/glitch_004.ogg"),
]
const _ENEMY_HIT: Array = [
	preload("res://assets/Audio/SFX/kenney_impactsounds/Audio/impactMetal_light_000.ogg"),
	preload("res://assets/Audio/SFX/kenney_impactsounds/Audio/impactMetal_light_001.ogg"),
	preload("res://assets/Audio/SFX/kenney_impactsounds/Audio/impactMetal_light_002.ogg"),
	preload("res://assets/Audio/SFX/kenney_impactsounds/Audio/impactMetal_light_003.ogg"),
	preload("res://assets/Audio/SFX/kenney_impactsounds/Audio/impactMetal_light_004.ogg"),
]
const _PLAYER_HIT: Array = [
	preload("res://assets/Audio/SFX/kenney_impactsounds/Audio/impactMetal_heavy_000.ogg"),
	preload("res://assets/Audio/SFX/kenney_impactsounds/Audio/impactMetal_heavy_001.ogg"),
	preload("res://assets/Audio/SFX/kenney_impactsounds/Audio/impactMetal_heavy_002.ogg"),
	preload("res://assets/Audio/SFX/kenney_impactsounds/Audio/impactMetal_heavy_003.ogg"),
	preload("res://assets/Audio/SFX/kenney_impactsounds/Audio/impactMetal_heavy_004.ogg"),
]
const _ENEMY_DEATH: Array = [
	preload("res://assets/Audio/SFX/kenney_impactsounds/Audio/impactMetal_medium_000.ogg"),
	preload("res://assets/Audio/SFX/kenney_impactsounds/Audio/impactMetal_medium_001.ogg"),
	preload("res://assets/Audio/SFX/kenney_impactsounds/Audio/impactMetal_medium_002.ogg"),
	preload("res://assets/Audio/SFX/kenney_impactsounds/Audio/impactMetal_medium_003.ogg"),
	preload("res://assets/Audio/SFX/kenney_impactsounds/Audio/impactMetal_medium_004.ogg"),
]
const _FOOTSTEP: Array = [
	preload("res://assets/Audio/SFX/kenney_impactsounds/Audio/footstep_concrete_000.ogg"),
	preload("res://assets/Audio/SFX/kenney_impactsounds/Audio/footstep_concrete_001.ogg"),
	preload("res://assets/Audio/SFX/kenney_impactsounds/Audio/footstep_concrete_002.ogg"),
	preload("res://assets/Audio/SFX/kenney_impactsounds/Audio/footstep_concrete_003.ogg"),
	preload("res://assets/Audio/SFX/kenney_impactsounds/Audio/footstep_concrete_004.ogg"),
]
const _PLAYER_DEATH: Array = [
	preload("res://assets/Audio/SFX/kenney_interface-sounds/Audio/error_001.ogg"),
]
const _PICKUP: Array = [
	preload("res://assets/Audio/SFX/kenney_interface-sounds/Audio/drop_001.ogg"),
]
const _CARD_SELECT: Array = [
	preload("res://assets/Audio/SFX/kenney_interface-sounds/Audio/select_001.ogg"),
]
const _FLOOR_CLEAR: Array = [
	preload("res://assets/Audio/SFX/kenney_interface-sounds/Audio/confirmation_001.ogg"),
	preload("res://assets/Audio/SFX/kenney_interface-sounds/Audio/maximize_001.ogg"),
]
const _UI_CLICK: Array = [
	preload("res://assets/Audio/SFX/kenney_uiaudio/Audio/click1.ogg"),
]

var _pool: Array[AudioStreamPlayer] = []
var _rr: int = 0

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)

func play(sfx: StringName, vol: float = 0.0) -> void:
	var bank: Array
	match sfx:
		"shoot":        bank = _SHOOT
		"enemy_hit":    bank = _ENEMY_HIT
		"player_hit":   bank = _PLAYER_HIT
		"enemy_death":  bank = _ENEMY_DEATH
		"footstep":     bank = _FOOTSTEP
		"player_death": bank = _PLAYER_DEATH
		"pickup":       bank = _PICKUP
		"card_select":  bank = _CARD_SELECT
		"floor_clear":  bank = _FLOOR_CLEAR
		"ui_click":     bank = _UI_CLICK
		_: return
	var player: AudioStreamPlayer = _pool[_rr % POOL_SIZE]
	_rr += 1
	player.stream = bank[randi() % bank.size()]
	player.volume_db = vol
	player.play()
