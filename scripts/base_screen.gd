extends Control

## Main gameplay screen: slot grid, buy/auto-spawn, drag-and-drop merging.

const NukeTierScript = preload("res://scripts/nuke_tier.gd")
const SLOT_SIZE := Vector2(100, 100)
const POOL_SIZE := 12
const LOCK_COST := 500.0
const LOCK_DURATION := 120.0
const LOCK_COOLDOWN := 300.0

@onready var event_banner: Label = $MarginContainer/VBoxContainer/EventBanner
@onready var slot_grid: GridContainer = $MarginContainer/VBoxContainer/SlotGrid
@onready var buy_button: Button = $MarginContainer/VBoxContainer/ButtonRow/BuyBombButton
@onready var upgrades_button: Button = $MarginContainer/VBoxContainer/ButtonRow/UpgradesButton
@onready var raid_button: Button = $MarginContainer/VBoxContainer/ButtonRow/RaidButton
@onready var lock_button: Button = $MarginContainer/VBoxContainer/ButtonRow/LockButton
@onready var redeem_button: Button = $MarginContainer/VBoxContainer/ButtonRow/RedeemButton
@onready var missions_button: Button = $MarginContainer/VBoxContainer/ButtonRow/MissionsButton
@onready var shield_panel: PanelContainer = $ShieldPanel
@onready var shield_label: Label = $ShieldPanel/ShieldLabel
@onready var redeem_popup: PanelContainer = $RedeemPopup
@onready var code_input: LineEdit = $RedeemPopup/VBoxContainer/CodeInput
@onready var redeem_submit_button: Button = $RedeemPopup/VBoxContainer/RedeemSubmitButton
@onready var redeem_close_button: Button = $RedeemPopup/VBoxContainer/RedeemCloseButton
@onready var redeem_result_label: Label = $RedeemPopup/VBoxContainer/RedeemResultLabel
@onready var daily_popup: PanelContainer = $DailyRewardPopup
@onready var daily_day_label: Label = $DailyRewardPopup/VBoxContainer/DayLabel
@onready var daily_amount_label: Label = $DailyRewardPopup/VBoxContainer/AmountLabel
@onready var claim_daily_button: Button = $DailyRewardPopup/VBoxContainer/ClaimDailyButton
@onready var missions_popup: PanelContainer = $MissionsPopup
@onready var missions_list: VBoxContainer = $MissionsPopup/VBoxContainer/MissionsList
@onready var missions_close_button: Button = $MissionsPopup/VBoxContainer/MissionsCloseButton
@onready var tutorial_popup: PanelContainer = $TutorialPopup
@onready var tutorial_label: Label = $TutorialPopup/VBoxContainer/TutorialLabel
@onready var tutorial_next_button: Button = $TutorialPopup/VBoxContainer/TutorialNextButton
@onready var welcome_popup: PanelContainer = $WelcomePopup
@onready var welcome_amount_label: Label = $WelcomePopup/VBoxContainer/AmountLabel
@onready var claim_button: Button = $WelcomePopup/VBoxContainer/ClaimButton
@onready var claim_x2_button: Button = $WelcomePopup/VBoxContainer/ClaimX2Button
@onready var auto_timer: Timer = $AutoSpawnTimer

var slot_nodes: Array[Control] = []
var slot_nuke: Array[Control] = []
var slot_tier: Array[int] = []

var dragged_tier: int = 0
var dragged_from: int = -1
var drag_visual: Control = null
var is_dragging: bool = false

# Floating label object pool
var _floating_pool: Array[Label] = []
var _floating_active: Array[Label] = []

var _pending_offline: float = 0.0
var _tutorial_step: int = 0
const TUTORIAL_STEPS := [
	"Buy a bomb using the Buy Bomb button.",
	"Drag a bomb and drop it on another of the same tier to merge.",
	"Raid AI bases to steal cash.",
	"Lock your base with a shield to protect it.",
	"Tap Next to finish the tutorial.",
]


func _ready() -> void:
	_build_slots()
	_build_floating_pool()
	buy_button.pressed.connect(_on_buy_pressed)
	upgrades_button.pressed.connect(_on_upgrades_pressed)
	raid_button.pressed.connect(_on_raid_pressed)
	lock_button.pressed.connect(_on_lock_pressed)
	redeem_button.pressed.connect(func(): redeem_popup.visible = true)
	missions_button.pressed.connect(_on_missions_pressed)
	auto_timer.timeout.connect(_on_auto_spawn)
	claim_button.pressed.connect(_on_claim_offline.bind(1))
	claim_x2_button.pressed.connect(_on_claim_x2)
	redeem_submit_button.pressed.connect(_on_redeem_submit)
	redeem_close_button.pressed.connect(func(): redeem_popup.visible = false)
	claim_daily_button.pressed.connect(_on_claim_daily)
	missions_close_button.pressed.connect(func(): missions_popup.visible = false)
	tutorial_next_button.pressed.connect(_on_tutorial_next)
	GameState.slots_changed.connect(_on_slots_changed)
	Economy.income_granted.connect(_on_income_granted)
	SaveManager.offline_earnings_ready.connect(_on_offline_ready)
	DailyRewardManager.daily_reward_available.connect(_on_daily_reward_available)
	EventManager.event_changed.connect(_on_event_changed)
	_refresh_all_slots()
	_update_auto_timer_wait()
	_update_event_banner()
	code_input.virtual_keyboard_enabled = true
	if not GameState.tutorial_completed:
		_tutorial_step = 0
		_show_tutorial_step()
	# Keyboard handling: keep popup visible; Godot handles panning partially.
	# Ensure code input doesn't get covered by setting popup top anchor (done in scene).


func _build_slots() -> void:
	for child in slot_grid.get_children():
		child.queue_free()
	slot_nodes.clear()
	slot_nuke.clear()
	slot_tier.clear()
	for i in range(GameState.slot_count):
		var slot := Control.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		var bg := ColorRect.new()
		bg.color = Color(0.15, 0.15, 0.2, 1.0)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(bg)
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
		slot_grid.add_child(slot)
		slot_nodes.append(slot)
		slot_nuke.append(null)
		slot_tier.append(0)


func _rebuild_slots_preserve() -> void:
	# Preserve existing tier layout into new slot count.
	var old_tiers := slot_tier.duplicate()
	_build_slots()
	for i in range(min(old_tiers.size(), slot_tier.size())):
		if old_tiers[i] > 0:
			slot_tier[i] = old_tiers[i]
			GameState.set_slot(i, old_tiers[i])
			_place_nuke(i, old_tiers[i])
	# fill remaining from GameState
	_refresh_all_slots()


func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if slot_tier[index] > 0 and not is_dragging:
					_start_drag(index)
			else:
				if is_dragging:
					_end_drag()


func _start_drag(index: int) -> void:
	is_dragging = true
	dragged_from = index
	dragged_tier = slot_tier[index]
	_clear_slot_visual(index)
	GameState.set_slot(index, 0)
	slot_tier[index] = 0
	drag_visual = _create_nuke_view(dragged_tier)
	drag_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_visual.z_index = 100
	add_child(drag_visual)
	drag_visual.pivot_offset = SLOT_SIZE * 0.5
	drag_visual.global_position = get_global_mouse_position() - SLOT_SIZE * 0.5


func _process(_delta: float) -> void:
	if is_dragging and drag_visual != null:
		drag_visual.global_position = get_global_mouse_position() - SLOT_SIZE * 0.5
	_update_shield_visual()


func _end_drag() -> void:
	if not is_dragging:
		return
	is_dragging = false
	var target := _nearest_slot_index(drag_visual.global_position + SLOT_SIZE * 0.5)
	if drag_visual != null:
		drag_visual.queue_free()
		drag_visual = null
	if target < 0:
		_place_nuke(dragged_from, dragged_tier)
		GameState.set_slot(dragged_from, dragged_tier)
		slot_tier[dragged_from] = dragged_tier
		dragged_from = -1
		dragged_tier = 0
		return
	if slot_tier[target] == 0:
		_place_nuke(target, dragged_tier)
		GameState.set_slot(target, dragged_tier)
		slot_tier[target] = dragged_tier
	elif slot_tier[target] == dragged_tier:
		var new_tier := mini(dragged_tier + 1, 15)
		_place_nuke(target, new_tier)
		GameState.set_slot(target, new_tier)
		slot_tier[target] = new_tier
		_play_merge_feedback(target)
		var mm = get_node_or_null("/root/MissionManager")
		if mm != null:
			mm.on_merge()
	else:
		var old_target_tier := slot_tier[target]
		_place_nuke(target, dragged_tier)
		GameState.set_slot(target, dragged_tier)
		slot_tier[target] = dragged_tier
		if dragged_from >= 0 and dragged_from != target:
			_place_nuke(dragged_from, old_target_tier)
			GameState.set_slot(dragged_from, old_target_tier)
			slot_tier[dragged_from] = old_target_tier
	dragged_from = -1
	dragged_tier = 0


func _nearest_slot_index(pos: Vector2) -> int:
	var best := -1
	var best_dist := 1.0e9
	for i in range(slot_nodes.size()):
		var center := slot_nodes[i].global_position + SLOT_SIZE * 0.5
		var d := center.distance_to(pos)
		if d < best_dist:
			best_dist = d
			best = i
	return best


func _place_nuke(slot_index: int, tier_number: int) -> void:
	_clear_slot_visual(slot_index)
	if tier_number <= 0:
		slot_tier[slot_index] = 0
		return
	var view := _create_nuke_view(tier_number)
	view.pivot_offset = SLOT_SIZE * 0.5
	slot_nodes[slot_index].add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot_nuke[slot_index] = view
	slot_tier[slot_index] = tier_number


func _clear_slot_visual(slot_index: int) -> void:
	if slot_nuke[slot_index] != null:
		slot_nuke[slot_index].queue_free()
		slot_nuke[slot_index] = null


func _create_nuke_view(tier_number: int) -> Control:
	var t: NukeTierScript = GameState.get_tier(tier_number)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.pivot_offset = SLOT_SIZE * 0.5
	var rect := ColorRect.new()
	rect.color = t.color if t != null else Color.GRAY
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(rect)
	var label := Label.new()
	label.text = str(tier_number)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color.BLACK)
	root.add_child(label)
	return root


func _play_merge_feedback(slot_index: int) -> void:
	var view := slot_nuke[slot_index]
	if view != null:
		var tween := create_tween()
		view.scale = Vector2(0.5, 0.5)
		tween.tween_property(view, "scale", Vector2(1.2, 1.2), 0.12)
		tween.tween_property(view, "scale", Vector2(1.0, 1.0), 0.12)
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 24
	particles.lifetime = 0.5
	particles.spread = 180.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 160.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	var tier_data: NukeTierScript = GameState.get_tier(slot_tier[slot_index])
	particles.color = tier_data.color if tier_data != null else Color.WHITE
	slot_nodes[slot_index].add_child(particles)
	particles.position = SLOT_SIZE * 0.5
	particles.emitting = true
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
	_on_merge_sound()
	_on_merge_haptics()


func _on_merge_sound() -> void:
	pass


func _on_merge_haptics() -> void:
	AudioManager.vibrate(100)


func _on_buy_pressed() -> void:
	if GameState.try_buy_tier1():
		_refresh_all_slots()


func _on_auto_spawn() -> void:
	if GameState.spawn_tier1_free():
		_refresh_all_slots()


func _on_upgrades_pressed() -> void:
	var main = get_tree().get_root().get_node_or_null("Main")
	if main:
		main.show_screen("upgrades")


func _on_raid_pressed() -> void:
	var main = get_tree().get_root().get_node_or_null("Main")
	if main:
		main.show_screen("raid")


func _on_lock_pressed() -> void:
	var now := Time.get_unix_time_from_system()
	if now < GameState.lock_until:
		return
	if now < GameState.lock_cooldown_until:
		return
	if GameState.cash < LOCK_COST:
		return
	GameState.cash -= LOCK_COST
	GameState.cash_changed.emit(GameState.cash)
	GameState.lock_until = now + LOCK_DURATION
	GameState.lock_cooldown_until = now + LOCK_COOLDOWN
	SaveManager.save()
	_update_shield_visual()


func _update_shield_visual() -> void:
	var now := Time.get_unix_time_from_system()
	if now < GameState.lock_until:
		shield_panel.visible = true
		var remaining := int(GameState.lock_until - now)
		shield_label.text = "SHIELDED %ds" % remaining
		lock_button.disabled = true
	else:
		shield_panel.visible = false
		if now < GameState.lock_cooldown_until:
			var remaining := int(GameState.lock_cooldown_until - now)
			lock_button.text = "Lock (%ds)" % remaining
			lock_button.disabled = true
		else:
			lock_button.text = "Lock Base"
			lock_button.disabled = false


func _on_income_granted(amount: float) -> void:
	_spawn_floating_text("+$" + Economy.format_number(amount), Vector2(size.x * 0.5, size.y * 0.4))


func _on_slots_changed() -> void:
	_refresh_all_slots()
	if GameState.slot_count > slot_nodes.size():
		_rebuild_slots_preserve()


func _refresh_all_slots() -> void:
	for i in range(slot_nodes.size()):
		var tier_val: int = 0
		if i < GameState.slots.size():
			tier_val = GameState.slots[i]
		slot_tier[i] = tier_val
		_clear_slot_visual(i)
		if tier_val > 0:
			_place_nuke(i, tier_val)


func _update_auto_timer_wait() -> void:
	var level := Economy.spawn_speed_level
	var wait := 4.0 / (1.0 + float(level) * 0.2)
	if wait < 0.5:
		wait = 0.5
	auto_timer.wait_time = wait


# Object pool for floating labels
func _build_floating_pool() -> void:
	for i in range(POOL_SIZE):
		var lbl := Label.new()
		lbl.visible = false
		lbl.modulate.a = 1.0
		add_child(lbl)
		_floating_pool.append(lbl)


func _get_pooled_label() -> Label:
	for lbl in _floating_pool:
		if not lbl.visible:
			return lbl
	# expand pool
	var lbl := Label.new()
	lbl.visible = false
	add_child(lbl)
	_floating_pool.append(lbl)
	return lbl


func _spawn_floating_text(text: String, pos: Vector2) -> void:
	var lbl := _get_pooled_label()
	lbl.text = text
	lbl.global_position = pos
	lbl.visible = true
	lbl.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 60.0, 0.8)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tween.finished.connect(_return_floating_label.bind(lbl))


func _return_floating_label(lbl: Label) -> void:
	lbl.visible = false


func _on_offline_ready(amount: float) -> void:
	_pending_offline = amount
	welcome_amount_label.text = "+" + Economy.format_number(amount)
	welcome_popup.visible = true


func _on_claim_offline(multiplier: int) -> void:
	GameState.add_cash(_pending_offline * float(multiplier))
	_pending_offline = 0.0
	welcome_popup.visible = false
	SaveManager.pending_offline = 0.0


func _on_claim_x2() -> void:
	AdService.show_rewarded_ad()
	# Stub grants immediately; grant x2.
	_on_claim_offline(2)


func _on_redeem_submit() -> void:
	var result := CodeManager.redeem(code_input.text)
	redeem_result_label.text = str(result.get("message", ""))
	if bool(result.get("ok", false)):
		code_input.text = ""


func _on_claim_daily() -> void:
	DailyRewardManager.claim()
	daily_popup.visible = false


func _on_daily_reward_available(day: int, amount: float) -> void:
	daily_day_label.text = "Day %d" % day
	daily_amount_label.text = "+" + Economy.format_number(amount)
	daily_popup.visible = true


func _on_missions_pressed() -> void:
	_refresh_missions_list()
	missions_popup.visible = true


func _refresh_missions_list() -> void:
	for child in missions_list.get_children():
		child.queue_free()
	for m in MissionManager.get_missions():
		if not (m is Dictionary):
			continue
		var id := str(m.get("id", ""))
		var target := int(m.get("target", 1))
		var progress := int(GameState.mission_progress.get(id, 0))
		var claimed := bool(GameState.mission_claimed.get(id, false))
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s (%d/%d)" % [str(m.get("name", id)), progress, target]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var btn := Button.new()
		btn.text = "Claimed" if claimed else "Claim"
		btn.disabled = claimed or progress < target
		btn.pressed.connect(_on_claim_mission.bind(id))
		row.add_child(btn)
		missions_list.add_child(row)


func _on_claim_mission(id: String) -> void:
	MissionManager.claim(id)
	_refresh_missions_list()


func _on_event_changed(_event_data: Dictionary) -> void:
	_update_event_banner()


func _update_event_banner() -> void:
	var ev := EventManager.active_event
	if ev is Dictionary and not ev.is_empty():
		event_banner.text = str(ev.get("name", "")) + " (+" + str(int(float(ev.get("income_bonus", 0.0)) * 100)) + "% income)"
		event_banner.visible = true
	else:
		event_banner.visible = false


func _show_tutorial_step() -> void:
	if _tutorial_step < TUTORIAL_STEPS.size():
		tutorial_label.text = TUTORIAL_STEPS[_tutorial_step]
		tutorial_popup.visible = true
	else:
		tutorial_popup.visible = false
		GameState.tutorial_completed = true
		SaveManager.save()


func _on_tutorial_next() -> void:
	_tutorial_step += 1
	_show_tutorial_step()