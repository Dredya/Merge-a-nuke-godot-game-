extends Node

## Audio/haptics settings hub.

var sound_enabled: bool = true
var music_enabled: bool = true
var vibration_enabled: bool = true
var fps_cap: int = 60


func set_sound_enabled(value: bool) -> void:
	sound_enabled = value


func set_music_enabled(value: bool) -> void:
	music_enabled = value


func set_vibration_enabled(value: bool) -> void:
	vibration_enabled = value


func set_fps_cap(value: int) -> void:
	fps_cap = value
	Engine.max_fps = value


func play_sfx(_name: String) -> void:
	if not sound_enabled:
		return
	# Stub: no audio assets yet.


func vibrate(duration_ms: int) -> void:
	if not vibration_enabled:
		return
	Input.vibrate_handheld(duration_ms)