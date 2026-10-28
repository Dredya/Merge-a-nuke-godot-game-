extends Control

## Settings: sound, music, vibration, FPS cap, reset save.

@onready var sound_check: CheckButton = $MarginContainer/VBoxContainer/SoundCheck
@onready var music_check: CheckButton = $MarginContainer/VBoxContainer/MusicCheck
@onready var vibration_check: CheckButton = $MarginContainer/VBoxContainer/VibrationCheck
@onready var fps_option: OptionButton = $MarginContainer/VBoxContainer/FpsOption
@onready var reset_button: Button = $MarginContainer/VBoxContainer/ResetButton
@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var confirm_dialog: AcceptDialog = $ConfirmDialog


func _ready() -> void:
	sound_check.button_pressed = AudioManager.sound_enabled
	music_check.button_pressed = AudioManager.music_enabled
	vibration_check.button_pressed = AudioManager.vibration_enabled
	sound_check.toggled.connect(func(v): AudioManager.set_sound_enabled(v))
	music_check.toggled.connect(func(v): AudioManager.set_music_enabled(v))
	vibration_check.toggled.connect(func(v): AudioManager.set_vibration_enabled(v))
	fps_option.add_item("30 FPS", 0)
	fps_option.add_item("60 FPS", 1)
	fps_option.selected = 0 if AudioManager.fps_cap <= 30 else 1
	fps_option.item_selected.connect(_on_fps_selected)
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back)
	confirm_dialog.confirmed.connect(_on_reset_confirmed)


func _on_fps_selected(index: int) -> void:
	AudioManager.set_fps_cap(30 if index == 0 else 60)


func _on_reset_pressed() -> void:
	confirm_dialog.popup_centered()


func _on_reset_confirmed() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("save.json"):
		dir.remove("save.json")
	# Reset state
	GameState.cash = 0.0
	GameState.slot_count = 6
	GameState.slots.clear()
	GameState.slots.resize(6)
	for i in range(6):
		GameState.slots[i] = 0
	GameState.lock_until = 0.0
	GameState.lock_cooldown_until = 0.0
	Economy.upgrade_levels.clear()
	for u in Economy.upgrades:
		if u is Dictionary:
			Economy.upgrade_levels[str(u.get("id", ""))] = 0
	Economy._recompute_multipliers()
	GameState.cash_changed.emit(GameState.cash)
	GameState.slots_changed.emit()
	var main = get_tree().get_root().get_node_or_null("Main")
	if main:
		main.show_screen("base")


func _on_back() -> void:
	var main = get_tree().get_root().get_node_or_null("Main")
	if main:
		main.show_screen("base")