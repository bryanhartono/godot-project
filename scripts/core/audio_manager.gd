# scripts/core/audio_manager.gd
extends Node

## One-shot SFX player. Call AudioManager.play_sfx(&"attack") anywhere.
## BGM tracks can be added to assets/Audio/BGM/ and loaded here when ready.

const _CLIPS: Dictionary = {
	&"attack":     "res://assets/Audio/SFX/kenney_impactsounds/Audio/impactPunch_heavy_002.ogg",
	&"move":       "res://assets/Audio/SFX/kenney_impactsounds/Audio/footstep_grass_000.ogg",
	&"ui_click":   "res://assets/Audio/SFX/kenney_impactsounds/Audio/impactGeneric_light_000.ogg",
	&"unit_death": "res://assets/Audio/SFX/kenney_impactsounds/Audio/impactSoft_heavy_002.ogg",
	&"place_unit": "res://assets/Audio/SFX/kenney_impactsounds/Audio/impactWood_medium_000.ogg",
}

var _streams: Dictionary = {}

func _ready() -> void:
	for key: StringName in _CLIPS:
		_streams[key] = load(_CLIPS[key])

func play_sfx(_name: StringName) -> void:
	var stream: AudioStream = _streams.get(_name)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
