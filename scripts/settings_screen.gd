extends Control

## Settings: audio, haptics, graphics quality, FPS cap and save reset.

@onready var sound_check: CheckButton = $Margin/VBox/Scroll/Content/AudioCard/AudioBox/SoundCheck
@onready var music_check: CheckButton = $Margin/VBox/Scroll/Content/AudioCard/AudioBox/MusicCheck
@onready var vibration_check: CheckButton = $Margin/VBox/Scroll/Content/AudioCard/AudioBox/VibrationCheck
@onready var quality_option: OptionButton = $Margin/VBox/Scroll/Content/VideoCard/VideoBox/QualityOption
@onready var fps_option: OptionButton = $Margin/VBox/Scroll/Content/VideoCard/VideoBox/FpsOption
@onready var reset_button: Button = $Margin/VBox/Scroll/Content/ResetButton
@onready var back_button: Button = $Margin/VBox/Scroll/Content/BackButton
@onready var confirm_dialog: AcceptDialog = $ConfirmDialog


func _ready() -> void:
	sound_check.button_pressed = AudioManager.sound_enabled
	music_check.button_pressed = AudioManager.music_enabled
	vibration_check.button_pressed = AudioManager.vibration_enabled

	quality_option.add_item("LOW", 0)
	quality_option.add_item("HIGH", 1)
	quality_option.selected = 0 if AudioManager.is_low_quality() else 1

	fps_option.add_item("30 FPS", 0)
	fps_option.add_item("60 FPS", 1)
	fps_option.selected = 0 if AudioManager.fps_cap <= 30 else 1

	sound_check.toggled.connect(_on_sound_toggled)
	music_check.toggled.connect(_on_music_toggled)
	vibration_check.toggled.connect(_on_vibration_toggled)
	quality_option.item_selected.connect(_on_quality_selected)
	fps_option.item_selected.connect(_on_fps_selected)
	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back)
	confirm_dialog.confirmed.connect(_on_reset_confirmed)


func _on_sound_toggled(value: bool) -> void:
	AudioManager.set_sound_enabled(value)


func _on_music_toggled(value: bool) -> void:
	AudioManager.set_music_enabled(value)


func _on_vibration_toggled(value: bool) -> void:
	AudioManager.set_vibration_enabled(value)


func _on_quality_selected(index: int) -> void:
	AudioManager.set_graphics_quality(0 if index == 0 else 1)


func _on_fps_selected(index: int) -> void:
	AudioManager.set_fps_cap(30 if index == 0 else 60)


func _on_reset_pressed() -> void:
	confirm_dialog.popup_centered()


func _on_reset_confirmed() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("save.json"):
		dir.remove("save.json")
	GameState.cash = 0.0
	GameState.slot_count = GameState.MAX_SLOTS
	GameState.slots.clear()
	GameState.slots.resize(GameState.MAX_SLOTS)
	for i in range(GameState.MAX_SLOTS):
		GameState.slots[i] = 0
	GameState.highest_tier_reached = 0
	GameState.lock_until = 0.0
	GameState.lock_cooldown_until = 0.0
	GameState.tutorial_completed = false
	GameState.mission_progress.clear()
	GameState.mission_claimed.clear()
	GameState.daily_streak = 0
	GameState.last_login_date = ""
	GameState.daily_claimed_date = ""
	GameState.mission_last_reset_date = ""
	SaveManager.pending_offline = 0.0
	SaveManager.pending_offline_seconds = 0.0
	Economy.upgrade_levels.clear()
	for upgrade in Economy.upgrades:
		if upgrade is Dictionary:
			Economy.upgrade_levels[str(upgrade.get("id", ""))] = 0
	Economy._recompute_multipliers()
	GameState.cash_changed.emit(GameState.cash)
	GameState.slots_changed.emit()
	SaveManager.save()
	var main := get_tree().root.get_node_or_null("Main")
	if main != null:
		main.call("show_screen", "base")


func _on_back() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main != null:
		main.call("show_screen", "base")
