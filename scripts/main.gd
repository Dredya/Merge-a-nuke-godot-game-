extends Control

## Main shell: safe area, screen switcher and the five-button bottom nav.

const SCREENS := {
	"base": "res://scenes/base_screen.tscn",
	"shop": "res://scenes/shop_screen.tscn",
	"raid": "res://scenes/raid_screen.tscn",
	"upgrades": "res://scenes/upgrades_screen.tscn",
	"settings": "res://scenes/settings_screen.tscn",
}
const C_LIME := Color("#B6F23C")
const C_MUTED := Color("#A9B6E0")

@onready var safe_area: MarginContainer = $SafeArea
@onready var screen_container: Control = $SafeArea/Shell/ScreenContainer
@onready var nav_bar: PanelContainer = $SafeArea/Shell/BottomNav
@onready var base_button: Button = $SafeArea/Shell/BottomNav/NavRow/BaseButton
@onready var shop_button: Button = $SafeArea/Shell/BottomNav/NavRow/ShopButton
@onready var raid_button: Button = $SafeArea/Shell/BottomNav/NavRow/RaidButton
@onready var upgrades_button: Button = $SafeArea/Shell/BottomNav/NavRow/UpgradesButton
@onready var settings_button: Button = $SafeArea/Shell/BottomNav/NavRow/SettingsButton

var _current_screen: Control = null
var _current_name: String = ""
var _nav_parts: Dictionary = {}


func _ready() -> void:
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	_setup_nav()
	show_screen("base")


func _apply_safe_area() -> void:
	var left := 12
	var top := 12
	var right := 12
	var bottom := 12
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var window_size := DisplayServer.window_get_size()
		if safe.size.x > 0 and safe.size.y > 0:
			left = maxi(12, safe.position.x)
			top = maxi(12, safe.position.y)
			right = maxi(12, window_size.x - safe.end.x)
			bottom = maxi(12, window_size.y - safe.end.y)
	safe_area.add_theme_constant_override("margin_left", left)
	safe_area.add_theme_constant_override("margin_top", top)
	safe_area.add_theme_constant_override("margin_right", right)
	safe_area.add_theme_constant_override("margin_bottom", bottom)


func _setup_nav() -> void:
	var defs: Array[Dictionary] = [
		{"name": "base", "label": "Base", "icon": "home", "button": base_button},
		{"name": "shop", "label": "Shop", "icon": "shop", "button": shop_button},
		{"name": "raid", "label": "Raid", "icon": "raid", "button": raid_button},
		{"name": "upgrades", "label": "Upgrades", "icon": "upgrades", "button": upgrades_button},
		{"name": "settings", "label": "Settings", "icon": "settings", "button": settings_button},
	]
	for def in defs:
		var button := def["button"] as Button
		var screen_name := str(def["name"])
		var parts := _decorate_nav_button(button, str(def["icon"]), str(def["label"]))
		_nav_parts[screen_name] = parts
		button.pressed.connect(show_screen.bind(screen_name))
		button.pressed.connect(_press_anim.bind(button))


func _decorate_nav_button(button: Button, icon_kind: String, label_text: String) -> Dictionary:
	button.text = ""
	button.theme_type_variation = &"NavButton"
	button.custom_minimum_size = Vector2(0.0, 112.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.name = "Content"
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	button.add_child(box)

	var icon := NavIcon.new()
	icon.name = "Icon"
	icon.kind = icon_kind
	icon.custom_minimum_size = Vector2(42.0, 42.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.icon_color = C_MUTED
	box.add_child(icon)

	var label := Label.new()
	label.name = "Label"
	label.text = label_text
	label.theme_type_variation = &"NavLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	var indicator := ColorRect.new()
	indicator.name = "ActiveIndicator"
	indicator.color = C_LIME
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	indicator.offset_left = 0.0
	indicator.offset_right = 0.0
	indicator.offset_top = -8.0
	indicator.offset_bottom = -3.0
	indicator.visible = false
	button.add_child(indicator)

	return {"button": button, "icon": icon, "label": label, "indicator": indicator}


func show_screen(screen_name: String) -> void:
	if screen_name == _current_name or not SCREENS.has(screen_name):
		_set_active_screen(screen_name)
		return
	if _current_screen != null:
		_current_screen.queue_free()
		_current_screen = null
	var packed: PackedScene = load(SCREENS[screen_name])
	if packed == null:
		return
	_current_screen = packed.instantiate() as Control
	screen_container.add_child(_current_screen)
	_current_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_current_name = screen_name
	_set_active_screen(screen_name)
	_animate_buttons(_current_screen)


func _set_active_screen(screen_name: String) -> void:
	for key in _nav_parts.keys():
		var parts: Dictionary = _nav_parts[key]
		var active := str(key) == screen_name
		var color := C_LIME if active else C_MUTED
		(parts["icon"] as NavIcon).icon_color = color
		var label := parts["label"] as Label
		label.add_theme_color_override("font_color", color)
		(parts["indicator"] as ColorRect).visible = active


func _animate_buttons(root: Node) -> void:
	for child in _all_buttons(root):
		if not child.pressed.is_connected(_press_anim):
			child.pressed.connect(_press_anim.bind(child))


func _all_buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button:
		result.append(node as Button)
	for child in node.get_children():
		result.append_array(_all_buttons(child))
	return result


func _press_anim(button: Button) -> void:
	if not is_instance_valid(button):
		return
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2(0.96, 0.96)
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
