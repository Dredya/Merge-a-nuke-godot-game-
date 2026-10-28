extends Node

## Audio, haptics and graphics settings hub. Settings are stored separately from
## the game save so they survive a save reset.

const SETTINGS_PATH := "user://settings.cfg"

var sound_enabled: bool = true
var music_enabled: bool = true
var vibration_enabled: bool = true
var fps_cap: int = 60
var graphics_quality: int = 1  # 0 = Low, 1 = High


func _ready() -> void:
	_load_settings()
	Engine.max_fps = fps_cap


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	sound_enabled = bool(config.get_value("audio", "sound", true))
	music_enabled = bool(config.get_value("audio", "music", true))
	vibration_enabled = bool(config.get_value("audio", "vibration", true))
	fps_cap = int(config.get_value("video", "fps_cap", 60))
	graphics_quality = int(config.get_value("video", "graphics_quality", 1))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "sound", sound_enabled)
	config.set_value("audio", "music", music_enabled)
	config.set_value("audio", "vibration", vibration_enabled)
	config.set_value("video", "fps_cap", fps_cap)
	config.set_value("video", "graphics_quality", graphics_quality)
	config.save(SETTINGS_PATH)


func set_sound_enabled(value: bool) -> void:
	sound_enabled = value
	_save_settings()


func set_music_enabled(value: bool) -> void:
	music_enabled = value
	_save_settings()


func set_vibration_enabled(value: bool) -> void:
	vibration_enabled = value
	_save_settings()


func set_fps_cap(value: int) -> void:
	fps_cap = value
	Engine.max_fps = value
	_save_settings()


func set_graphics_quality(value: int) -> void:
	graphics_quality = clampi(value, 0, 1)
	_save_settings()


func is_low_quality() -> bool:
	return graphics_quality == 0


func play_sfx(_name: String) -> void:
	if not sound_enabled:
		return
	# Stub: no audio assets yet.


func vibrate(duration_ms: int) -> void:
	if not vibration_enabled:
		return
	Input.vibrate_handheld(duration_ms)
