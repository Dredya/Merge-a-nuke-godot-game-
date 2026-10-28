extends Control

## Upgrades screen: spend cash to raise the free-spawn tier and offline cap.

var _cash_label: Label
var _list: VBoxContainer
var _buttons: Dictionary = {}


func _ready() -> void:
	_build_ui()
	Economy.upgrades_loaded.connect(_refresh)
	Economy.upgrade_purchased.connect(func(_id): _refresh())
	GameState.cash_changed.connect(_on_cash_changed)
	_refresh()


func _on_cash_changed(_cash: float) -> void:
	if _cash_label == null:
		return
	_cash_label.text = "$" + Economy.format_number(GameState.cash)
	for id in _buttons.keys():
		var button := _buttons[id] as Button
		if button != null:
			button.disabled = not Economy.can_buy_upgrade(str(id))


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "UPGRADES"
	title.theme_type_variation = &"TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_cash_label = Label.new()
	_cash_label.theme_type_variation = &"CashAmount"
	_cash_label.add_theme_font_size_override("font_size", 44)
	_cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_cash_label)

	var hint := Label.new()
	hint.text = "Permanent boosts for your base."
	hint.theme_type_variation = &"MutedLabel"
	box.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)


func _refresh() -> void:
	if _cash_label == null:
		return
	_cash_label.text = "$" + Economy.format_number(GameState.cash)
	for child in _list.get_children():
		child.queue_free()
	_buttons.clear()
	for upgrade in Economy.upgrades:
		if not (upgrade is Dictionary):
			continue
		var id := str(upgrade.get("id", ""))
		var level := Economy.get_upgrade_level(id)
		var max_level := int(upgrade.get("max_level", 1))
		var cost := Economy.get_upgrade_cost(id)
		var card := PanelContainer.new()
		card.theme_type_variation = &"PanelCard"
		_list.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)

		var badge_panel := PanelContainer.new()
		badge_panel.custom_minimum_size = Vector2(82, 82)
		badge_panel.add_theme_stylebox_override("panel", _badge_style(id))
		row.add_child(badge_panel)
		var badge := Label.new()
		badge.text = _badge_text(id)
		badge.theme_type_variation = &"TitleLabel"
		badge.add_theme_font_size_override("font_size", 22 if id == "spawn_tier" else 30)
		badge.add_theme_color_override("font_color", Color("#0B1020"))
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_panel.add_child(badge)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var name_label := Label.new()
		name_label.text = str(upgrade.get("name", id))
		name_label.theme_type_variation = &"WhiteLabel"
		info.add_child(name_label)
		var level_label := Label.new()
		level_label.text = "LEVEL %d / %d  •  %s" % [level, max_level, _effect_text(id)]
		level_label.theme_type_variation = &"MutedLabel"
		level_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(level_label)
		var cost_label := Label.new()
		cost_label.text = "MAXED" if level >= max_level else "COST $%s" % Economy.format_number(float(cost))
		cost_label.theme_type_variation = &"GoldLabel"
		info.add_child(cost_label)

		var buy := Button.new()
		buy.theme_type_variation = &"GreenButton"
		buy.custom_minimum_size = Vector2(200, 72)
		buy.add_theme_font_size_override("font_size", 25)
		buy.text = "MAX" if level >= max_level else "UPGRADE"
		buy.disabled = not Economy.can_buy_upgrade(id)
		buy.pressed.connect(_on_buy.bind(id))
		row.add_child(buy)
		_buttons[id] = buy


func _badge_text(id: String) -> String:
	match id:
		"spawn_tier":
			return "TIER"
		"offline_cap":
			return "OFF"
		_:
			return "+"


func _badge_style(id: String) -> StyleBoxFlat:
	var color := Color("#B6F23C")
	match id:
		"spawn_tier":
			color = Color("#FFC83D")
		"offline_cap":
			color = Color("#4FE0FF")
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


func _effect_text(id: String) -> String:
	match id:
		"spawn_tier":
			return "free bombs spawn at a higher tier"
		"offline_cap":
			return "offline earning limit"
		_:
			return "bonus"


func _on_buy(id: String) -> void:
	Economy.buy_upgrade(id)
	_refresh()
