extends Control

## Shop: bomb purchases plus daily reward, redeem codes and missions.

const CARD_AVATAR := 82.0

var _content: VBoxContainer
var _cash_label: Label
var _buy_buttons: Array[Button] = []
var _buy_tiers: Array[int] = []
var _daily_day_label: Label
var _daily_amount_label: Label
var _daily_button: Button
var _code_input: LineEdit
var _code_result: Label
var _missions_box: VBoxContainer


func _ready() -> void:
	_build_ui()
	GameState.cash_changed.connect(func(_cash): _update_states())
	MissionManager.mission_progress_changed.connect(func(_id, _progress): _refresh_missions())
	_refresh_all()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	margin.add_child(root_box)

	var header := HBoxContainer.new()
	root_box.add_child(header)
	var title := Label.new()
	title.text = "SHOP"
	title.theme_type_variation = &"TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_cash_label = Label.new()
	_cash_label.theme_type_variation = &"CashAmount"
	_cash_label.add_theme_font_size_override("font_size", 44)
	_cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_cash_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_box.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)

	_build_rewards()
	_build_missions()
	_build_bombs()


func _section(title_text: String) -> void:
	var label := Label.new()
	label.text = title_text
	label.theme_type_variation = &"H2"
	label.add_theme_color_override("font_color", Color("#FFC83D"))
	_content.add_child(label)


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"PanelCard"
	return card


func _build_rewards() -> void:
	_section("REWARDS")

	var daily_card := _card()
	_content.add_child(daily_card)
	var daily_row := HBoxContainer.new()
	daily_row.add_theme_constant_override("separation", 14)
	daily_card.add_child(daily_row)
	var daily_text := VBoxContainer.new()
	daily_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	daily_row.add_child(daily_text)
	var daily_title := Label.new()
	daily_title.text = "Daily Reward"
	daily_title.theme_type_variation = &"WhiteLabel"
	daily_text.add_child(daily_title)
	_daily_day_label = Label.new()
	_daily_day_label.theme_type_variation = &"MutedLabel"
	daily_text.add_child(_daily_day_label)
	_daily_amount_label = Label.new()
	_daily_amount_label.theme_type_variation = &"GoldLabel"
	daily_text.add_child(_daily_amount_label)
	_daily_button = Button.new()
	_daily_button.theme_type_variation = &"GreenButton"
	_daily_button.custom_minimum_size = Vector2(190, 72)
	_daily_button.add_theme_font_size_override("font_size", 26)
	_daily_button.text = "CLAIM"
	_daily_button.pressed.connect(_on_claim_daily)
	daily_row.add_child(_daily_button)

	var code_card := _card()
	_content.add_child(code_card)
	var code_box := VBoxContainer.new()
	code_box.add_theme_constant_override("separation", 8)
	code_card.add_child(code_box)
	var code_title := Label.new()
	code_title.text = "Redeem Code"
	code_title.theme_type_variation = &"WhiteLabel"
	code_box.add_child(code_title)
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 10)
	code_box.add_child(code_row)
	_code_input = LineEdit.new()
	_code_input.placeholder_text = "ENTER CODE"
	_code_input.virtual_keyboard_enabled = true
	_code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_input.custom_minimum_size = Vector2(0, 64)
	code_row.add_child(_code_input)
	var redeem := Button.new()
	redeem.theme_type_variation = &"OrangeButton"
	redeem.text = "REDEEM"
	redeem.custom_minimum_size = Vector2(180, 64)
	redeem.add_theme_font_size_override("font_size", 26)
	redeem.pressed.connect(_on_redeem)
	code_row.add_child(redeem)
	_code_result = Label.new()
	_code_result.theme_type_variation = &"MutedLabel"
	code_box.add_child(_code_result)


func _build_missions() -> void:
	_section("MISSIONS")
	_missions_box = VBoxContainer.new()
	_missions_box.add_theme_constant_override("separation", 8)
	_content.add_child(_missions_box)


func _build_bombs() -> void:
	_section("BOMBS")
	for tier_data in GameState.tiers:
		var tier := int(tier_data.tier)
		if tier <= 1:
			continue
		var card := _card()
		_content.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)

		var avatar := PanelContainer.new()
		avatar.custom_minimum_size = Vector2(CARD_AVATAR, CARD_AVATAR)
		avatar.add_theme_stylebox_override("panel", _avatar_style(tier_data.color))
		row.add_child(avatar)
		var avatar_label := Label.new()
		avatar_label.text = str(tier)
		avatar_label.theme_type_variation = &"TitleLabel"
		avatar_label.add_theme_font_size_override("font_size", 40)
		avatar_label.add_theme_color_override("font_color", _readable_text(tier_data.color))
		avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		avatar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		avatar.add_child(avatar_label)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		row.add_child(info)
		var name_label := Label.new()
		name_label.text = str(tier_data.name)
		name_label.theme_type_variation = &"WhiteLabel"
		info.add_child(name_label)
		var tier_label := Label.new()
		tier_label.text = "TIER %d" % tier
		tier_label.theme_type_variation = &"MutedLabel"
		info.add_child(tier_label)
		var income := Label.new()
		income.text = "+$%s / sec" % Economy.format_number(tier_data.income_per_sec)
		income.theme_type_variation = &"IncomeLabel"
		info.add_child(income)

		var buy := Button.new()
		buy.theme_type_variation = &"OrangeButton"
		buy.custom_minimum_size = Vector2(210, 72)
		buy.add_theme_font_size_override("font_size", 25)
		buy.text = "BUY  $%s" % Economy.format_number(float(tier_data.buy_cost))
		buy.pressed.connect(_on_buy_tier.bind(tier))
		row.add_child(buy)
		_buy_buttons.append(buy)
		_buy_tiers.append(tier)


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


func _readable_text(color: Color) -> Color:
	var luminance := 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
	return Color("#0B1020") if luminance > 0.55 else Color.WHITE


func _refresh_all() -> void:
	_update_states()
	_refresh_daily()
	_refresh_missions()


func _update_states() -> void:
	_cash_label.text = "$" + Economy.format_number(GameState.cash)
	for i in range(_buy_buttons.size()):
		var tier_data := GameState.get_tier(_buy_tiers[i])
		if tier_data == null:
			continue
		_buy_buttons[i].disabled = GameState.cash < float(tier_data.buy_cost) or GameState.empty_slot_count() <= 0
	_daily_button.disabled = GameState.daily_claimed_date == Time.get_date_string_from_system()


func _refresh_daily() -> void:
	var day := maxi(GameState.daily_streak, 1)
	var amount := DailyRewardManager.get_reward_amount(day)
	_daily_day_label.text = "DAY %d STREAK" % day
	_daily_amount_label.text = "+$" + Economy.format_number(amount)
	var claimed := GameState.daily_claimed_date == Time.get_date_string_from_system()
	_daily_button.text = "CLAIMED" if claimed else "CLAIM"


func _refresh_missions() -> void:
	if _missions_box == null:
		return
	for child in _missions_box.get_children():
		child.queue_free()
	var missions := MissionManager.get_missions()
	if missions.is_empty():
		var empty := Label.new()
		empty.text = "No missions today."
		empty.theme_type_variation = &"MutedLabel"
		_missions_box.add_child(empty)
		return
	for mission in missions:
		if not (mission is Dictionary):
			continue
		var id := str(mission.get("id", ""))
		var target := int(mission.get("target", 1))
		var progress := int(GameState.mission_progress.get(id, 0))
		var claimed := bool(GameState.mission_claimed.get(id, false))
		var card := _card()
		_missions_box.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var name_label := Label.new()
		name_label.text = str(mission.get("name", id))
		name_label.theme_type_variation = &"WhiteLabel"
		info.add_child(name_label)
		var progress_label := Label.new()
		progress_label.text = "%d / %d  •  reward $%s" % [
			progress, target, Economy.format_number(float(mission.get("reward_cash", 0.0)))
		]
		progress_label.theme_type_variation = &"MutedLabel"
		info.add_child(progress_label)
		var claim := Button.new()
		claim.theme_type_variation = &"GreenButton"
		claim.custom_minimum_size = Vector2(160, 64)
		claim.add_theme_font_size_override("font_size", 24)
		claim.text = "CLAIMED" if claimed else "CLAIM"
		claim.disabled = claimed or progress < target
		claim.pressed.connect(_on_claim_mission.bind(id))
		row.add_child(claim)


func _on_buy_tier(tier: int) -> void:
	var tier_data := GameState.get_tier(tier)
	if tier_data == null or GameState.cash < float(tier_data.buy_cost):
		return
	for i in range(GameState.slots.size()):
		if GameState.slots[i] == 0:
			GameState.cash -= float(tier_data.buy_cost)
			GameState.cash_changed.emit(GameState.cash)
			GameState.set_slot(i, tier)
			SaveManager.save()
			AudioManager.play_sfx("buy")
			_update_states()
			return


func _on_claim_daily() -> void:
	if GameState.daily_claimed_date == Time.get_date_string_from_system():
		return
	DailyRewardManager.claim()
	GameState.cash_changed.emit(GameState.cash)
	_refresh_daily()
	_update_states()


func _on_redeem() -> void:
	var result := CodeManager.redeem(_code_input.text)
	_code_result.text = str(result.get("message", ""))
	if bool(result.get("ok", false)):
		_code_input.text = ""
		GameState.cash_changed.emit(GameState.cash)
		_update_states()


func _on_claim_mission(id: String) -> void:
	if MissionManager.claim(id):
		GameState.cash_changed.emit(GameState.cash)
		_update_states()
	_refresh_missions()
