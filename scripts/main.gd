extends Control

## Main shell: bottom navigation switching screens.

const SCREENS := {
	"base": "res://scenes/base_screen.tscn",
	"shop": "res://scenes/shop_screen.tscn",
	"raid": "res://scenes/raid_screen.tscn",
	"upgrades": "res://scenes/upgrades_screen.tscn",
	"settings": "res://scenes/settings_screen.tscn",
}

@onready var screen_container: Control = $MarginContainer/VBoxContainer/ScreenContainer
@onready var base_button: Button = $MarginContainer/VBoxContainer/BottomNav/BaseButton
@onready var shop_button: Button = $MarginContainer/VBoxContainer/BottomNav/ShopButton
@onready var raid_button: Button = $MarginContainer/VBoxContainer/BottomNav/RaidButton
@onready var upgrades_button: Button = $MarginContainer/VBoxContainer/BottomNav/UpgradesButton
@onready var settings_button: Button = $MarginContainer/VBoxContainer/BottomNav/SettingsButton

var _current_screen: Control = null
var _current_name: String = ""


func _ready() -> void:
	base_button.pressed.connect(func(): show_screen("base"))
	shop_button.pressed.connect(func(): show_screen("shop"))
	raid_button.pressed.connect(func(): show_screen("raid"))
	upgrades_button.pressed.connect(func(): show_screen("upgrades"))
	settings_button.pressed.connect(func(): show_screen("settings"))
	for btn in [base_button, shop_button, raid_button, upgrades_button, settings_button]:
		btn.pressed.connect(_press_anim.bind(btn))
	show_screen("base")


func show_screen(name: String) -> void:
	if name == _current_name:
		return
	if not SCREENS.has(name):
		return
	if _current_screen != null:
		_current_screen.queue_free()
		_current_screen = null
	var packed: PackedScene = load(SCREENS[name])
	_current_screen = packed.instantiate()
	screen_container.add_child(_current_screen)
	_current_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_current_name = name
	_animate_buttons(_current_screen)


func _animate_buttons(root: Node) -> void:
	for child in _all_buttons(root):
		if not child.pressed.is_connected(_press_anim):
			child.pressed.connect(_press_anim.bind(child))


func _all_buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button:
		result.append(node)
	for c in node.get_children():
		result.append_array(_all_buttons(c))
	return result


func _press_anim(btn: Button) -> void:
	var tween := create_tween()
	btn.scale = Vector2(0.95, 0.95)
	btn.pivot_offset = btn.size * 0.5
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)