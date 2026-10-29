extends Control

## Shop: daily reward and missions. Bombs now arrive for free on the base.

var _content: VBoxContainer
var _cash_label: Label
var _daily_day_label: Label
var _daily_amount_label: Label
var _daily_button: Button
var _missions_box: VBoxContainer


func _ready() -> void:
	_build_ui()
	GameState.cash_changed.connect(func(_cash): _update_states())
	MissionManager.mission_progress_changed.connect(func(_id, _progress): _refresh_missions())
	IAPService.purchase_completed.connect(_on_iap_completed)
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
	_build_iap()
	_build_missions()


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


func _build_iap() -> void:
	_section("BUY CASH")
	for product in IAPService.get_products():
		if not (product is Dictionary):
			continue
		var pid := str(product.get("id", ""))
		var card := _card()
		_content.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var title := Label.new()
		title.text = str(product.get("name", pid))
		title.theme_type_variation = &"WhiteLabel"
		info.add_child(title)
		var amount := Label.new()
		amount.text = "+$" + Economy.format_number(float(product.get("cash", 0.0)))
		amount.theme_type_variation = &"GoldLabel"
		info.add_child(amount)
		var buy := Button.new()
		buy.theme_type_variation = &"GreenButton"
		buy.custom_minimum_size = Vector2(180, 64)
		buy.add_theme_font_size_override("font_size", 24)
		buy.text = str(product.get("label", "GET"))
		buy.pressed.connect(_on_buy_cash.bind(pid))
		row.add_child(buy)


func _build_missions() -> void:
	_section("MISSIONS")
	_missions_box = VBoxContainer.new()
	_missions_box.add_theme_constant_override("separation", 8)
	_content.add_child(_missions_box)


func _refresh_all() -> void:
	_update_states()
	_refresh_daily()
	_refresh_missions()


func _update_states() -> void:
	_cash_label.text = "$" + Economy.format_number(GameState.cash)
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


func _on_claim_daily() -> void:
	if GameState.daily_claimed_date == Time.get_date_string_from_system():
		return
	DailyRewardManager.claim()
	GameState.cash_changed.emit(GameState.cash)
	_refresh_daily()
	_update_states()


func _on_claim_mission(id: String) -> void:
	if MissionManager.claim(id):
		GameState.cash_changed.emit(GameState.cash)
		_update_states()
	_refresh_missions()


func _on_buy_cash(product_id: String) -> void:
	IAPService.purchase(product_id)


func _on_iap_completed(product_id: String) -> void:
	var reward := IAPService.get_reward(product_id)
	if reward > 0.0:
		GameState.add_cash(reward)
		GameState.cash_changed.emit(GameState.cash)
	_update_states()
