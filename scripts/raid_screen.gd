extends Control

## Raid screen: 3D diorama on top, target cards below, launch animation + loot popup.

const AVATAR_COLORS := [
	Color("#FF7A9A"), Color("#4FE0FF"), Color("#B6F23C"), Color("#FFC83D"),
	Color("#C77DFF"), Color("#FF9A3D"), Color("#6AD7FF"), Color("#8F7CFF"),
]

@onready var world_view: SubViewportContainer = $Margin/VBox/WorldFrame/WorldView
@onready var sub_viewport: SubViewport = $Margin/VBox/WorldFrame/WorldView/SubViewport
@onready var cash_label: Label = $Margin/VBox/Header/CashLabel
@onready var targets_box: VBoxContainer = $Margin/VBox/Scroll/Targets
@onready var result_popup: Control = $ResultPopup
@onready var result_amount: Label = $ResultPopup/Center/Panel/VBox/Amount
@onready var result_ok: Button = $ResultPopup/Center/Panel/VBox/OkButton

var world: RaidWorld
var _raiding: bool = false
var _launch_buttons: Array[Button] = []
var _cooldown_widgets: Array[Dictionary] = []
var _cooldown_timer: Timer


func _ready() -> void:
	world = RaidWorld.new()
	world.name = "RaidWorld"
	sub_viewport.add_child(world)
	world.setup(AudioManager.is_low_quality(), GameState.highest_tier_reached)

	result_ok.pressed.connect(_close_result)
	RaidService.targets_refreshed.connect(_refresh_targets)
	GameState.cash_changed.connect(func(_cash): _update_cash())
	_refresh_targets()
	_update_cash()

	_cooldown_timer = Timer.new()
	_cooldown_timer.wait_time = 1.0
	_cooldown_timer.autostart = true
	_cooldown_timer.timeout.connect(_update_cooldowns)
	add_child(_cooldown_timer)


func _close_result() -> void:
	result_popup.visible = false
	if world != null:
		world.reset_raid()


func _update_cash() -> void:
	cash_label.text = "$" + Economy.format_number(GameState.cash)


func _refresh_targets() -> void:
	for child in targets_box.get_children():
		child.queue_free()
	_launch_buttons.clear()
	_cooldown_widgets.clear()
	var normal: Array = []
	var revenge: Array = []
	for target in RaidService.get_targets():
		if not (target is Dictionary):
			continue
		if bool(target.get("is_revenge", false)):
			revenge.append(target)
		else:
			normal.append(target)

	_add_section("ENEMY BASES")
	if normal.is_empty():
		_add_empty("No targets available. Check back soon.")
	for target in normal:
		_add_target_card(target, false)

	_add_section("REVENGE")
	if revenge.is_empty():
		_add_empty("No one has raided you yet. Revenge targets appear here.")
	for target in revenge:
		_add_target_card(target, true)


func _add_section(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"H2"
	label.add_theme_color_override("font_color", Color("#FFC83D"))
	targets_box.add_child(label)


func _add_empty(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"MutedLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	targets_box.add_child(label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	targets_box.add_child(spacer)


func _add_target_card(target: Dictionary, is_revenge: bool) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"PanelCard"
	targets_box.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)

	var avatar := PanelContainer.new()
	avatar.custom_minimum_size = Vector2(82, 82)
	var avatar_color: Color = AVATAR_COLORS[absi(hash(str(target.get("id", "")))) % AVATAR_COLORS.size()]
	avatar.add_theme_stylebox_override("panel", _avatar_style(avatar_color))
	row.add_child(avatar)
	var avatar_label := Label.new()
	avatar_label.text = str(target.get("name", "?")).substr(0, 1).to_upper()
	avatar_label.theme_type_variation = &"TitleLabel"
	avatar_label.add_theme_font_size_override("font_size", 40)
	avatar_label.add_theme_color_override("font_color", _readable_text(avatar_color))
	avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(avatar_label)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = str(target.get("name", "Base"))
	name_label.theme_type_variation = &"WhiteLabel"
	info.add_child(name_label)
	var loot := Label.new()
	loot.text = "Loot: $" + Economy.format_number(float(target.get("cash", 0.0)))
	loot.theme_type_variation = &"GoldLabel"
	info.add_child(loot)
	if is_revenge:
		var tag := Label.new()
		tag.text = "REVENGE TARGET"
		tag.theme_type_variation = &"MutedLabel"
		info.add_child(tag)

	var locked := bool(target.get("locked", false))
	var now := Time.get_unix_time_from_system()
	var cooldown := float(target.get("cooldown_until", 0.0))
	if locked:
		var tag_panel := PanelContainer.new()
		tag_panel.custom_minimum_size = Vector2(170, 72)
		tag_panel.add_theme_stylebox_override("panel", _tag_style())
		row.add_child(tag_panel)
		var tag := Label.new()
		tag.text = "LOCKED"
		tag.theme_type_variation = &"MutedLabel"
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag_panel.add_child(tag)
		return

	var launch := Button.new()
	launch.custom_minimum_size = Vector2(190, 72)
	launch.add_theme_font_size_override("font_size", 24)
	if now < cooldown:
		launch.theme_type_variation = &"SmallButton"
		launch.text = "WAIT %ds" % int(ceil(cooldown - now))
		launch.disabled = true
		_cooldown_widgets.append({"button": launch, "target": target.duplicate(), "revenge": is_revenge})
	elif is_revenge:
		launch.theme_type_variation = &"GreenButton"
		launch.text = "REVENGE"
	else:
		launch.theme_type_variation = &"OrangeButton"
		launch.text = "LAUNCH"
	launch.pressed.connect(_on_launch.bind(target.duplicate()))
	row.add_child(launch)
	_launch_buttons.append(launch)
	if _raiding:
		launch.disabled = true


func _avatar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#0B1020")
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _tag_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#2A3355")
	style.border_color = Color("#0B1020")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _update_cooldowns() -> void:
	var now := Time.get_unix_time_from_system()
	for entry in _cooldown_widgets:
		var button := entry["button"] as Button
		var target := entry["target"] as Dictionary
		if button == null:
			continue
		var remaining := float(target.get("cooldown_until", 0.0)) - now
		if remaining <= 0.0:
			button.disabled = false
			button.theme_type_variation = &"GreenButton" if bool(entry["revenge"]) else &"OrangeButton"
			button.text = "REVENGE" if bool(entry["revenge"]) else "LAUNCH"
		else:
			button.disabled = true
			button.text = "WAIT %ds" % int(ceil(remaining))


func _readable_text(color: Color) -> Color:
	var luminance := 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
	return Color("#0B1020") if luminance > 0.55 else Color.WHITE


func _on_launch(target: Dictionary) -> void:
	if _raiding:
		return
	if bool(target.get("locked", false)):
		return
	var now := Time.get_unix_time_from_system()
	if now < float(target.get("cooldown_until", 0.0)):
		return
	_raiding = true
	for button in _launch_buttons:
		button.disabled = true
	var stolen := maxf(float(target.get("cash", 0.0)) * 0.2, 1.0)
	AudioManager.play_sfx("raid")
	await world.launch()
	GameState.add_cash(stolen)
	var mission_manager := get_node_or_null("/root/MissionManager")
	if mission_manager != null:
		mission_manager.call("on_raid")
	# Consume loot and apply a short cooldown.
	for entry in RaidService.targets:
		if entry is Dictionary and str(entry.get("id", "")) == str(target.get("id", "")):
			entry["cash"] = maxf(float(entry.get("cash", 0.0)) - stolen, 0.0)
			entry["cooldown_until"] = Time.get_unix_time_from_system() + 30.0
	SaveManager.save()
	result_amount.text = "+$" + Economy.format_number(stolen)
	result_popup.visible = true
	_raiding = false
	_refresh_targets()
