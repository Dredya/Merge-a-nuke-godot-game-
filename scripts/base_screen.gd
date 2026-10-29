extends Control

## Base screen: 3D plot, touch drag/merge, HUD, merge effects and retention popups.

const FONT_PATH := "res://assets/fonts/LilitaOne-Regular.ttf"
const DRAG_LIFT := 0.55
const PICK_RADIUS := 1.18
const INCOME_LABEL_POOL := 14
const LOCK_COST := 500.0
const LOCK_DURATION := 120.0
const LOCK_COOLDOWN := 300.0
## A press that moves less than this many pixels is treated as a tap (select),
## not a drag.
const TAP_MOVE_THRESHOLD := 16.0
const MERGE_HINT := "MERGE TWO IDENTICAL BOMBS TO LEVEL UP"

@onready var world_view: SubViewportContainer = $VBox/Middle/WorldView
@onready var sub_viewport: SubViewport = $VBox/Middle/WorldView/SubViewport
@onready var middle: Control = $VBox/Middle
@onready var plot_input: Control = $VBox/Middle/PlotInput
@onready var flash_overlay: ColorRect = $VBox/Middle/FlashOverlay
@onready var screen_glow: ColorRect = $VBox/Middle/ScreenGlow
@onready var cash_label: Label = $VBox/TopHud/HudRow/CashPanel/CashBox/CashAmount
@onready var income_label: Label = $VBox/TopHud/HudRow/CashPanel/CashBox/IncomeLabel
@onready var locked_label: Label = $VBox/TopHud/HudRow/LockPanel/LockBox/LockedLabel
@onready var lock_timer_label: Label = $VBox/TopHud/HudRow/LockPanel/LockBox/LockTimer
@onready var lock_button: Button = $VBox/TopHud/HudRow/LockPanel/LockBox/LockButton
@onready var event_banner: Label = $EventBannerPanel/EventBanner
@onready var free_progress: ProgressBar = $VBox/BottomControls/BottomBox/ControlRow/FreePanel/FreeRow/FreeProgress
@onready var free_seconds: Label = $VBox/BottomControls/BottomBox/ControlRow/FreePanel/FreeRow/FreeSeconds
@onready var sell_button: Button = $VBox/BottomControls/BottomBox/ControlRow/SellButton
@onready var merge_hint: Label = $VBox/BottomControls/BottomBox/MergeHint
@onready var milestone_panel: PanelContainer = $MilestoneToastPanel
@onready var milestone_label: Label = $MilestoneToastPanel/MilestoneToastLabel
@onready var tutorial_popup: Control = $TutorialPopup
@onready var tutorial_label: Label = $TutorialPopup/Center/Panel/Box/TutorialLabel
@onready var tutorial_next_button: Button = $TutorialPopup/Center/Panel/Box/TutorialNextButton
@onready var daily_popup: Control = $DailyPopup
@onready var daily_day_label: Label = $DailyPopup/Center/Panel/Box/DayLabel
@onready var daily_amount_label: Label = $DailyPopup/Center/Panel/Box/AmountLabel
@onready var claim_daily_button: Button = $DailyPopup/Center/Panel/Box/ClaimDailyButton
@onready var offline_popup: Control = $OfflinePopup
@onready var offline_time_label: Label = $OfflinePopup/Center/Panel/Box/OfflineTime
@onready var offline_amount_label: Label = $OfflinePopup/Center/Panel/Box/OfflineAmount
@onready var claim_x2_button: Button = $OfflinePopup/Center/Panel/Box/ClaimX2Button
@onready var claim_button: Button = $OfflinePopup/Center/Panel/Box/ClaimButton

var world: BaseWorld
var slot_bombs: Array[Bomb] = []
var slot_tiers: Array[int] = []

var _low_quality: bool = false
var _is_dragging: bool = false
var _is_animating: bool = false
var _drag_bomb: Bomb = null
var _drag_from: int = -1
var _drag_tier: int = 0
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_start_local: Vector2 = Vector2.ZERO
var _drag_moved: bool = false
var _suppress_slot_refresh: bool = false
var _selected_slot: int = -1

var _auto_timer: Timer
var _ui_timer: Timer
var _income_pool: Array[Label3D] = []
var _label_font: Font
var _rng := RandomNumberGenerator.new()

var _tutorial_step: int = 0
var _pending_daily: Dictionary = {}
var _daily_popup_shown: bool = false
var _milestone_tween: Tween

const TUTORIAL_STEPS := [
	"A free bomb arrives every few seconds. Wait for two of the same tier.",
	"Drag a bomb onto another bomb of the same tier to merge them.",
	"Tap a bomb to select it, then press SELL to cash it in.",
	"Higher tiers earn far more cash per second.",
	"Lock your base to protect your cash from raids.",
	"Raids, missions and codes are in the other tabs.",
]


func _ready() -> void:
	_rng.randomize()
	_low_quality = AudioManager.is_low_quality()
	world = BaseWorld.new()
	world.name = "BaseWorld"
	sub_viewport.add_child(world)
	var dims := _grid_dims(GameState.slot_count)
	world.setup(_low_quality, dims.x, dims.y)
	world_view.resized.connect(_sync_viewport_size)
	if middle != null and not middle.resized.is_connected(_sync_viewport_size):
		middle.resized.connect(_sync_viewport_size)
	var root_vp := get_viewport()
	if root_vp != null and not root_vp.size_changed.is_connected(_sync_viewport_size):
		root_vp.size_changed.connect(_sync_viewport_size)
	_sync_viewport_size()
	_cap_popup_widths()

	slot_tiers.resize(GameState.slot_count)
	slot_bombs.resize(GameState.slot_count)
	for i in range(GameState.slot_count):
		slot_tiers[i] = 0
		slot_bombs[i] = null

	_build_income_pool()
	_ensure_slot_capacity()
	_refresh_all_slots()

	plot_input.gui_input.connect(_on_plot_input)
	lock_button.pressed.connect(_on_lock_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	claim_daily_button.pressed.connect(_on_claim_daily)
	tutorial_next_button.pressed.connect(_on_tutorial_next)
	claim_x2_button.pressed.connect(_on_claim_offline_x2)
	claim_button.pressed.connect(func(): _claim_offline(1))
	GameState.slots_changed.connect(_on_slots_changed)
	GameState.slot_count_changed.connect(_on_slot_count_changed)
	GameState.cash_changed.connect(func(_cash): _update_hud())
	Economy.income_granted.connect(_on_income_granted)
	DailyRewardManager.daily_reward_available.connect(_on_daily_reward_available)
	SaveManager.offline_earnings_ready.connect(_on_offline_ready)
	EventManager.event_changed.connect(func(_event): _update_event_banner())

	_auto_timer = Timer.new()
	_auto_timer.wait_time = _spawn_wait()
	_auto_timer.autostart = true
	_auto_timer.timeout.connect(_on_auto_spawn)
	add_child(_auto_timer)

	_ui_timer = Timer.new()
	_ui_timer.wait_time = 0.2
	_ui_timer.autostart = true
	_ui_timer.timeout.connect(_update_hud)
	add_child(_ui_timer)

	_update_hud()
	_update_event_banner()
	if GameState.tutorial_completed:
		_check_pending_popups()
	else:
		_tutorial_step = 0
		_show_tutorial_step()
	get_tree().create_timer(0.6).timeout.connect(_check_pending_popups)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_viewport_size()
		_cap_popup_widths()


func _cap_popup_widths() -> void:
	if tutorial_popup == null:
		return
	var vp_w := get_viewport().get_visible_rect().size.x
	var cap := func(panel: PanelContainer, base_min: float):
		if panel != null:
			panel.custom_minimum_size.x = min(base_min, max(240.0, vp_w - 40.0))
	var tp := tutorial_popup.get_node_or_null("Center/Panel") as PanelContainer
	cap.call(tp, 760.0)
	if daily_popup != null:
		var dp := daily_popup.get_node_or_null("Center/Panel") as PanelContainer
		cap.call(dp, 720.0)
	if offline_popup != null:
		var op := offline_popup.get_node_or_null("Center/Panel") as PanelContainer
		cap.call(op, 780.0)
	var event_panel := get_node_or_null("EventBannerPanel") as PanelContainer
	if event_panel != null:
		event_panel.custom_minimum_size.x = min(540.0, max(200.0, vp_w - 40.0))


func _sync_viewport_size() -> void:
	if world_view == null or sub_viewport == null:
		return
	# Drive the SubViewport from the parent area, not from the container:
	# SubViewportContainer's minimum size follows the SubViewport size, so
	# reading world_view.size would self-lock the 3D view at its initial size
	# and overflow over the HUD.
	var area := middle.size if middle != null else world_view.size
	var target := Vector2i(maxi(2, int(area.x)), maxi(2, int(area.y)))
	if sub_viewport.size != target:
		sub_viewport.size = target
	if world != null and world.has_method("fit_camera"):
		world.call("fit_camera", target)


func _ensure_slot_capacity() -> void:
	if GameState.slots.size() != GameState.slot_count:
		GameState.slots.resize(GameState.slot_count)
		for i in range(GameState.slot_count):
			if GameState.slots[i] < 0:
				GameState.slots[i] = 0
	for i in range(GameState.slots.size()):
		GameState.slots[i] = clampi(GameState.slots[i], 0, GameState.MAX_TIER)
	GameState.slot_count = clampi(GameState.slot_count, 6, GameState.MAX_SLOTS)


func _grid_dims(n: int) -> Vector2i:
	# Pick cols <= rows so the board stays tall on phones, and cols*rows == n.
	# For a perfect square (e.g. 16) this yields cols == rows.
	var best_cols := 1
	var c := 1
	while c * c <= n:
		if n % c == 0:
			best_cols = c
		c += 1
	return Vector2i(best_cols, n / best_cols)


func _spawn_wait() -> float:
	# Fixed spawn cadence; progression comes from the Spawn Tier upgrade.
	return 6.0


# --- Board visuals ----------------------------------------------------------

func _refresh_all_slots() -> void:
	if _is_dragging or _is_animating:
		return
	for i in range(GameState.slot_count):
		if slot_bombs[i] != null:
			slot_bombs[i].queue_free()
			slot_bombs[i] = null
	for i in range(GameState.slot_count):
		var tier := GameState.slots[i]
		slot_tiers[i] = tier
		if tier > 0:
			_create_bomb(i, tier, false)


func _create_bomb(index: int, tier: int, pop: bool) -> Bomb:
	var tier_data := GameState.get_tier(tier)
	var bomb := BombFactory.build(tier, _low_quality, tier_data)
	bomb.name = "Bomb_%d_T%d" % [index, tier]
	bomb.position = world.slot_position(index)
	world.add_child(bomb)
	slot_bombs[index] = bomb
	slot_tiers[index] = tier
	if pop:
		bomb.scale = Vector3(0.2, 0.2, 0.2)
		var tween := create_tween()
		tween.tween_property(bomb, "scale", Vector3(1.12, 1.12, 1.12), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(bomb, "scale", Vector3.ONE, 0.10)
	return bomb


func _board_copy() -> Array[int]:
	var copy: Array[int] = []
	copy.resize(GameState.slot_count)
	for i in range(GameState.slot_count):
		copy[i] = GameState.slots[i]
	return copy


func _on_slots_changed() -> void:
	if _suppress_slot_refresh or _is_dragging or _is_animating:
		return
	_refresh_all_slots()
	_update_hud()


func _on_slot_count_changed() -> void:
	_clear_selection()
	# Make sure GameState.slots matches the new count before touching the visuals.
	_ensure_slot_capacity()
	var dims := _grid_dims(GameState.slot_count)
	var cols := dims.x
	var rows := dims.y
	if world != null:
		world.rebuild(cols, rows)
		if world.has_method("fit_camera"):
			var vp: Vector2i = world_view.size if world_view != null else Vector2i(1080, 1920)
			world.call("fit_camera", vp)
	# Free any bombs still referenced by the old (smaller) arrays before resizing.
	for i in range(slot_bombs.size()):
		if slot_bombs[i] != null:
			slot_bombs[i].queue_free()
			slot_bombs[i] = null
	slot_tiers.resize(GameState.slot_count)
	slot_bombs.resize(GameState.slot_count)
	for i in range(slot_tiers.size()):
		slot_tiers[i] = 0
		slot_bombs[i] = null
	_refresh_all_slots()
	_update_hud()


# --- Touch picking and dragging --------------------------------------------

func _on_plot_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			if not _is_dragging and not _is_animating:
				_try_start_drag(button.position)
		elif _is_dragging:
			_finish_drag(button.position)
	elif event is InputEventMouseMotion and _is_dragging:
		_move_drag((event as InputEventMouseMotion).position)


func _to_viewport(local_position: Vector2) -> Vector2:
	var container_size := world_view.size
	if container_size.x <= 1.0 or container_size.y <= 1.0:
		return Vector2.ZERO
	if sub_viewport.size.x <= 0 or sub_viewport.size.y <= 0:
		return Vector2.ZERO
	var result := Vector2(
		local_position.x / container_size.x * float(sub_viewport.size.x),
		local_position.y / container_size.y * float(sub_viewport.size.y)
	)
	# Keep the point inside the render target so a stale/out-of-range coordinate
	# cannot produce a misleading ground-plane hit after a resize.
	result.x = clampf(result.x, 0.0, float(sub_viewport.size.x) - 1.0)
	result.y = clampf(result.y, 0.0, float(sub_viewport.size.y) - 1.0)
	return result


func _ground_point(local_position: Vector2, height: float) -> Variant:
	var viewport_point := _to_viewport(local_position)
	var origin := world.camera.project_ray_origin(viewport_point)
	var direction := world.camera.project_ray_normal(viewport_point)
	var plane := Plane(Vector3.UP, -height)
	return plane.intersects_ray(origin, direction)


func _pick_bomb(viewport_point: Vector2) -> int:
	# Cheap analytic ray-vs-sphere pick against occupied slots (no physics bodies).
	var origin := world.camera.project_ray_origin(viewport_point)
	var direction := world.camera.project_ray_normal(viewport_point)
	var best := -1
	var best_t := 100000.0
	for i in range(GameState.slot_count):
		if GameState.slots[i] <= 0:
			continue
		var center := world.slot_position(i) + Vector3(0.0, 0.16, 0.0)
		var oc := origin - center
		var b := oc.dot(direction)
		var c := oc.length_squared() - 1.0 * 1.0
		var discriminant := b * b - c
		if discriminant < 0.0:
			continue
		var t := -b - sqrt(discriminant)
		if t > 0.0 and t < best_t:
			best_t = t
			best = i
	return best


func _nearest_slot(point: Vector3) -> int:
	var best := -1
	var best_distance := 100000.0
	for i in range(GameState.slot_count):
		var slot_pos := world.slot_position(i)
		var distance := Vector2(point.x - slot_pos.x, point.z - slot_pos.z).length()
		if distance < best_distance:
			best_distance = distance
			best = i
	if best_distance > PICK_RADIUS:
		return -1
	return best


func _try_start_drag(local_position: Vector2) -> void:
	var slot := _pick_bomb(_to_viewport(local_position))
	if slot < 0:
		var hit: Variant = _ground_point(local_position, BaseWorld.PAD_TOP_Y)
		if hit != null:
			slot = _nearest_slot(hit as Vector3)
	if slot < 0 or GameState.slots[slot] <= 0 or slot_bombs[slot] == null:
		# Pressing empty ground/tarmac clears the current selection.
		_clear_selection()
		return
	_drag_start_local = local_position
	_drag_moved = false
	_is_dragging = true
	_drag_from = slot
	_drag_tier = slot_tiers[slot]
	_drag_bomb = slot_bombs[slot]
	slot_bombs[slot] = null
	slot_tiers[slot] = 0
	var shadow := _drag_bomb.get_node_or_null("BlobShadow") as Node3D
	if shadow != null:
		shadow.visible = false
	_drag_bomb.scale = Vector3.ONE * 1.08
	var slot_pos := world.slot_position(slot)
	_drag_offset = Vector2.ZERO
	var hit: Variant = _ground_point(local_position, BaseWorld.PAD_TOP_Y)
	if hit != null:
		var hit_point := hit as Vector3
		_drag_offset = Vector2(slot_pos.x - hit_point.x, slot_pos.z - hit_point.z)
	_drag_bomb.position = Vector3(slot_pos.x, BaseWorld.PAD_TOP_Y + DRAG_LIFT, slot_pos.z)
	world.show_slot_highlight(slot)
	AudioManager.play_sfx("pick")


func _move_drag(local_position: Vector2) -> void:
	if _drag_bomb == null:
		return
	if not _drag_moved and local_position.distance_to(_drag_start_local) > TAP_MOVE_THRESHOLD:
		# Past the tap threshold this is a real drag; drop any prior selection.
		_drag_moved = true
		_clear_selection()
	var hit: Variant = _ground_point(local_position, BaseWorld.PAD_TOP_Y)
	if hit == null:
		return
	var p := hit as Vector3
	_drag_bomb.position = Vector3(
		p.x + _drag_offset.x,
		BaseWorld.PAD_TOP_Y + DRAG_LIFT,
		p.z + _drag_offset.y
	)
	# Sell zone takes priority when the dragged bomb hovers over it.
	var sell_center := world.sell_zone_center()
	var dxz := Vector2(_drag_bomb.position.x - sell_center.x, _drag_bomb.position.z - sell_center.z)
	if dxz.length() <= 1.7:
		world.set_sell_highlight(true)
		world.hide_slot_highlight()
		return
	world.set_sell_highlight(false)
	var slot := _nearest_slot(_drag_bomb.position)
	if slot >= 0:
		world.show_slot_highlight(slot)
	else:
		world.hide_slot_highlight()


func _finish_drag(local_position: Vector2) -> void:
	if _drag_bomb == null:
		_is_dragging = false
		_drag_from = -1
		return
	_move_drag(local_position)
	_is_dragging = false
	world.set_sell_highlight(false)
	if not _drag_moved:
		# A tap (no significant movement) selects the bomb instead of moving it.
		var tapped := _drag_from
		_return_drag()
		_select_slot(tapped)
		return
	_clear_selection()
	# Selling takes priority over placement.
	var sell_center := world.sell_zone_center()
	var dxz := Vector2(_drag_bomb.position.x - sell_center.x, _drag_bomb.position.z - sell_center.z)
	if dxz.length() <= 1.7:
		_sell_dragged()
		return
	var target := _nearest_slot(_drag_bomb.position)
	world.hide_slot_highlight()
	if target < 0 or target == _drag_from:
		_return_drag()
		return
	var target_tier := GameState.slots[target]
	if target_tier <= 0:
		_move_to_slot(target)
	elif target_tier == _drag_tier:
		if _drag_tier >= GameState.MAX_TIER:
			_return_drag()
		else:
			_merge_into(target)
	else:
		_swap_with(target)


func _return_drag() -> void:
	if _drag_bomb == null:
		return
	_is_animating = true
	world.set_sell_highlight(false)
	var from := _drag_from
	var bomb := _drag_bomb
	var tween := create_tween()
	tween.tween_property(bomb, "position", world.slot_position(from), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	bomb.scale = Vector3.ONE
	var shadow := bomb.get_node_or_null("BlobShadow") as Node3D
	if shadow != null:
		shadow.visible = not _low_quality
	if from >= 0:
		slot_bombs[from] = bomb
		slot_tiers[from] = _drag_tier
	_drag_bomb = null
	_drag_from = -1
	_drag_tier = 0
	_is_animating = false


func _sell_dragged() -> void:
	if _drag_bomb == null:
		_is_animating = false
		return
	_is_animating = true
	var from := _drag_from
	var bomb := _drag_bomb
	var tier := _drag_tier
	var value := _sell_value(tier)
	# Fly the bomb to the sell bin, then grant cash.
	var bin_pos := world.sell_zone_center()
	var tween := create_tween()
	tween.tween_property(bomb, "position", bin_pos + Vector3(0.0, 0.6, 0.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(bomb, "scale", Vector3(0.1, 0.1, 0.1), 0.14)
	await tween.finished
	bomb.queue_free()
	# Free the slot.
	if from >= 0:
		slot_bombs[from] = null
		slot_tiers[from] = 0
	var new_slots := _board_copy()
	if from >= 0:
		new_slots[from] = 0
	GameState.commit_slots(new_slots)
	GameState.add_cash(value)
	_spawn_sell_label(bin_pos, value)
	AudioManager.play_sfx("claim")
	AudioManager.vibrate(20)
	SaveManager.save()
	_drag_bomb = null
	_drag_from = -1
	_drag_tier = 0
	_is_animating = false
	_update_hud()


# --- Tap selection and Sell button ------------------------------------------

func _select_slot(slot: int) -> void:
	# Selection is validated against game state, not visuals: during a drag the
	# visual reference is detached from the slot until the return tween ends.
	if slot < 0 or slot >= GameState.slot_count or GameState.slots[slot] <= 0:
		_clear_selection()
		return
	_selected_slot = slot
	world.show_slot_highlight(slot)
	_update_selection_ui()


func _clear_selection() -> void:
	if _selected_slot < 0:
		return
	_selected_slot = -1
	if world != null:
		world.hide_slot_highlight()
	_update_selection_ui()


func _sell_value(tier: int) -> float:
	var tier_data := GameState.get_tier(tier)
	var income := 0.0
	if tier_data != null:
		income = tier_data.income_per_sec
	return maxf(1.0, income * Economy.sell_income_seconds)


func _on_sell_pressed() -> void:
	if _selected_slot < 0 or _is_dragging or _is_animating:
		return
	var slot := _selected_slot
	if slot >= GameState.slot_count or GameState.slots[slot] <= 0 or slot_bombs[slot] == null:
		_clear_selection()
		return
	_clear_selection()
	_sell_slot(slot)


func _sell_slot(slot: int) -> void:
	# Sell the bomb where it sits so the action reads clearly even though the 3D
	# sell bin sits at the edge of the framed view.
	if slot < 0 or slot >= GameState.slot_count:
		return
	var bomb := slot_bombs[slot]
	if bomb == null or GameState.slots[slot] <= 0:
		return
	_is_animating = true
	var tier := GameState.slots[slot]
	var value := _sell_value(tier)
	var slot_pos := world.slot_position(slot)
	var tween := create_tween()
	tween.tween_property(bomb, "position", slot_pos + Vector3(0.0, 1.1, 0.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(bomb, "scale", Vector3(0.12, 0.12, 0.12), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	bomb.queue_free()
	slot_bombs[slot] = null
	slot_tiers[slot] = 0
	var new_slots := _board_copy()
	new_slots[slot] = 0
	GameState.commit_slots(new_slots)
	GameState.add_cash(value)
	_spawn_sell_label(slot_pos, value)
	AudioManager.play_sfx("claim")
	AudioManager.vibrate(20)
	SaveManager.save()
	_is_animating = false
	_update_hud()


func _spawn_sell_label(pos: Vector3, value: float) -> void:
	var label := _get_income_label()
	if label == null:
		return
	label.text = "+$" + Economy.format_number(value)
	label.position = pos + Vector3(0.0, 1.4, 0.0)
	label.modulate = Color("#FFC83D")
	label.outline_modulate = Color("#0E1420")
	label.visible = true
	var start_y := label.position.y
	var tween := create_tween()
	tween.tween_property(label, "position:y", start_y + 0.9, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tween.finished.connect(func(): label.visible = false)


func _move_to_slot(target: int) -> void:
	if _drag_bomb == null:
		return
	_is_animating = true
	var from := _drag_from
	var bomb := _drag_bomb
	var new_slots := _board_copy()
	new_slots[target] = _drag_tier
	new_slots[from] = 0
	GameState.commit_slots(new_slots)
	slot_bombs[target] = bomb
	slot_bombs[from] = null
	slot_tiers[target] = _drag_tier
	slot_tiers[from] = 0
	bomb.scale = Vector3.ONE
	var shadow := bomb.get_node_or_null("BlobShadow") as Node3D
	if shadow != null:
		shadow.visible = not _low_quality
	var tween := create_tween()
	tween.tween_property(bomb, "position", world.slot_position(target), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	_drag_bomb = null
	_drag_from = -1
	_drag_tier = 0
	_is_animating = false
	SaveManager.save()


func _swap_with(target: int) -> void:
	if _drag_bomb == null:
		return
	_is_animating = true
	var from := _drag_from
	var bomb := _drag_bomb
	var other := slot_bombs[target]
	var other_tier := slot_tiers[target]
	var new_slots := _board_copy()
	new_slots[target] = _drag_tier
	new_slots[from] = other_tier
	GameState.commit_slots(new_slots)
	slot_bombs[target] = bomb
	slot_bombs[from] = other
	slot_tiers[target] = _drag_tier
	slot_tiers[from] = other_tier
	bomb.scale = Vector3.ONE
	var shadow := bomb.get_node_or_null("BlobShadow") as Node3D
	if shadow != null:
		shadow.visible = not _low_quality
	var tween := create_tween()
	tween.tween_property(bomb, "position", world.slot_position(target), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if other != null:
		var shadow_other := other.get_node_or_null("BlobShadow") as Node3D
		if shadow_other != null:
			shadow_other.visible = not _low_quality
		tween.parallel().tween_property(other, "position", world.slot_position(from), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	_drag_bomb = null
	_drag_from = -1
	_drag_tier = 0
	_is_animating = false
	SaveManager.save()


func _merge_into(target: int) -> void:
	if _drag_bomb == null:
		return
	_is_animating = true
	var from := _drag_from
	var bomb := _drag_bomb
	var other := slot_bombs[target]
	var target_pos := world.slot_position(target)
	# Both bombs fly together toward the target before the flash.
	var midpoint := (bomb.position + target_pos) * 0.5 + Vector3(0.0, 0.42, 0.0)
	var tween := create_tween()
	tween.tween_property(bomb, "position", midpoint, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if other != null:
		tween.parallel().tween_property(other, "position", midpoint, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished

	var new_tier := mini(_drag_tier + 1, GameState.MAX_TIER)
	bomb.scale = Vector3.ONE
	if other != null:
		other.scale = Vector3.ONE
	_play_merge_fx(target, new_tier)
	bomb.queue_free()
	if other != null:
		other.queue_free()
	slot_bombs[from] = null
	slot_bombs[target] = null
	slot_tiers[from] = 0
	slot_tiers[target] = 0

	var new_slots := _board_copy()
	new_slots[from] = 0
	new_slots[target] = new_tier
	GameState.commit_slots(new_slots)
	var merged := _create_bomb(target, new_tier, true)
	merged.position = target_pos
	_show_milestone(new_tier)

	var mission_manager := get_node_or_null("/root/MissionManager")
	if mission_manager != null:
		mission_manager.call("on_merge")
	SaveManager.save()
	_drag_bomb = null
	_drag_from = -1
	_drag_tier = 0
	_is_animating = false


# --- Merge VFX --------------------------------------------------------------

func _play_merge_fx(target: int, new_tier: int) -> void:
	var tier_data: NukeTier = GameState.get_tier(new_tier)
	var fx_color := Color.WHITE
	if tier_data != null:
		fx_color = tier_data.glow_color
	var fx_pos := world.slot_position(target) + Vector3(0.0, 0.58, 0.0)

	_spawn_flash(fx_pos, fx_color)
	_spawn_shockwave(fx_pos, fx_color)
	if not _low_quality:
		_spawn_particles(fx_pos, fx_color)

	flash_overlay.visible = true
	flash_overlay.color = Color(1.0, 1.0, 1.0, 0.42)
	var flash_tween := create_tween()
	flash_tween.tween_property(flash_overlay, "color:a", 0.0, 0.28)
	flash_tween.finished.connect(func(): flash_overlay.visible = false)

	if new_tier >= GameState.MAX_TIER and not _low_quality:
		screen_glow.visible = true
		screen_glow.color = Color(1.0, 1.0, 1.0, 0.26)
		var glow_tween := create_tween()
		glow_tween.tween_method(_set_singularity_glow, 0.0, 1.0, 0.7)
		glow_tween.finished.connect(func(): screen_glow.visible = false)

	AudioManager.play_sfx("merge")
	AudioManager.vibrate(30)


func _set_singularity_glow(t: float) -> void:
	screen_glow.color = Color.from_hsv(fmod(t * 0.55, 1.0), 0.65, 1.0, 0.18 * (1.0 - t))


func _show_milestone(tier: int) -> void:
	var tier_data := GameState.get_tier(tier)
	if tier_data == null:
		return
	# Only the four milestone tiers get a toast; renamed income tiers do not.
	if tier not in [25, 50, 75, 100]:
		return
	milestone_label.text = "MILESTONE  •  " + tier_data.name.to_upper()
	milestone_panel.visible = true
	milestone_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if _milestone_tween != null and _milestone_tween.is_valid():
		_milestone_tween.kill()
	_milestone_tween = create_tween()
	_milestone_tween.tween_property(milestone_panel, "modulate:a", 1.0, 0.15)
	_milestone_tween.tween_interval(1.05)
	_milestone_tween.tween_property(milestone_panel, "modulate:a", 0.0, 0.35)
	_milestone_tween.finished.connect(func(): milestone_panel.visible = false)


func _spawn_flash(pos: Vector3, color: Color) -> void:
	var mat := LowPoly.material_unique(color, color, 5.0, true, 0.9)
	var flash := MeshInstance3D.new()
	flash.mesh = LowPoly.sphere(0.38, 8, 4)
	flash.material_override = mat
	flash.position = pos
	flash.scale = Vector3.ONE * 0.25
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 2.1, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.30)
	tween.finished.connect(func(): flash.queue_free())


func _spawn_shockwave(pos: Vector3, color: Color) -> void:
	var mat := LowPoly.material_unique(color, color, 2.6, true, 0.85)
	var ring := MeshInstance3D.new()
	ring.mesh = LowPoly.torus(0.45, 0.045, 18, 5)
	ring.material_override = mat
	ring.position = Vector3(pos.x, BaseWorld.PAD_TOP_Y + 0.20, pos.z)
	ring.scale = Vector3.ONE * 0.25
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 2.9, 0.52).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.55)
	tween.finished.connect(func(): ring.queue_free())


func _spawn_particles(pos: Vector3, color: Color) -> void:
	var particles := CPUParticles3D.new()
	particles.position = pos
	particles.amount = 24
	particles.lifetime = 0.75
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.18
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 180.0
	particles.gravity = Vector3(0.0, -2.2, 0.0)
	particles.initial_velocity_min = 1.4
	particles.initial_velocity_max = 3.4
	particles.scale_amount_min = 0.04
	particles.scale_amount_max = 0.10
	particles.color = color
	particles.mesh = LowPoly.sphere(1.0, 4, 2)
	particles.material_override = LowPoly.material(color, 0.0, 0.2, color, 2.8, true)
	particles.emitting = true
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(particles)
	get_tree().create_timer(1.2).timeout.connect(particles.queue_free)


# --- Income labels ----------------------------------------------------------

func _build_income_pool() -> void:
	_label_font = load(FONT_PATH) as Font
	for i in range(INCOME_LABEL_POOL):
		var label := Label3D.new()
		label.font = _label_font
		label.font_size = 56
		label.pixel_size = 0.006
		label.outline_size = 14
		label.modulate = Color("#B6F23C")
		label.outline_modulate = Color("#0E1420")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.double_sided = true
		label.no_depth_test = true
		label.visible = false
		world.add_child(label)
		_income_pool.append(label)


func _on_income_granted(amount: float) -> void:
	if amount <= 0.0 or _income_pool.is_empty():
		return
	var occupied: Array[int] = []
	for i in range(GameState.slot_count):
		if GameState.slots[i] > 0:
			occupied.append(i)
	if occupied.is_empty():
		return
	var slot := occupied[_rng.randi_range(0, occupied.size() - 1)]
	var label := _get_income_label()
	if label == null:
		return
	label.text = "+$" + Economy.format_number(amount)
	label.position = world.slot_position(slot) + Vector3(0.0, 1.55, 0.0)
	label.modulate = Color("#B6F23C")
	label.outline_modulate = Color("#0E1420")
	label.visible = true
	var start_y := label.position.y
	var tween := create_tween()
	tween.tween_property(label, "position:y", start_y + 0.95, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tween.parallel().tween_property(label, "outline_modulate:a", 0.0, 0.9)
	tween.finished.connect(func(): label.visible = false)


func _get_income_label() -> Label3D:
	for label in _income_pool:
		if not label.visible:
			return label
	return null


# --- HUD --------------------------------------------------------------------

func _on_lock_pressed() -> void:
	var now := Time.get_unix_time_from_system()
	if now < GameState.lock_until or now < GameState.lock_cooldown_until:
		return
	if GameState.cash < LOCK_COST:
		return
	GameState.cash -= LOCK_COST
	GameState.cash_changed.emit(GameState.cash)
	GameState.lock_until = now + LOCK_DURATION
	GameState.lock_cooldown_until = now + LOCK_COOLDOWN
	SaveManager.save()
	AudioManager.play_sfx("lock")
	_update_hud()


func _update_hud() -> void:
	var income := GameState.income_per_second_total() * Economy.event_income_multiplier
	cash_label.text = "$" + Economy.format_number(GameState.cash)
	income_label.text = "+$" + Economy.format_number(income) + " / sec"

	var now := Time.get_unix_time_from_system()
	if now < GameState.lock_until:
		locked_label.text = "BASE LOCKED"
		locked_label.add_theme_color_override("font_color", Color("#6FA0FF"))
		lock_timer_label.text = _format_time(GameState.lock_until - now)
		lock_timer_label.add_theme_color_override("font_color", Color("#6FA0FF"))
		lock_button.visible = false
	elif now < GameState.lock_cooldown_until:
		locked_label.text = "BASE OPEN"
		locked_label.add_theme_color_override("font_color", Color("#B8C2D8"))
		lock_timer_label.text = "READY " + _format_time(GameState.lock_cooldown_until - now)
		lock_timer_label.add_theme_color_override("font_color", Color("#B8C2D8"))
		lock_button.visible = true
		lock_button.disabled = true
		lock_button.text = "COOLDOWN"
	else:
		locked_label.text = "BASE OPEN"
		locked_label.add_theme_color_override("font_color", Color("#B8C2D8"))
		lock_timer_label.text = "NO SHIELD"
		lock_timer_label.add_theme_color_override("font_color", Color("#B8C2D8"))
		lock_button.visible = true
		lock_button.disabled = GameState.cash < LOCK_COST
		lock_button.text = "LOCK $%d" % int(LOCK_COST)

	if GameState.empty_slot_count() <= 0:
		free_progress.value = 100.0
		free_seconds.text = "FULL"
	else:
		var wait := maxf(_auto_timer.wait_time, 0.01)
		var left := clampf(_auto_timer.time_left, 0.0, wait)
		free_progress.value = (1.0 - left / wait) * 100.0
		free_seconds.text = "%ds" % int(ceil(left))

	_update_selection_ui()


func _update_selection_ui() -> void:
	if sell_button == null:
		return
	# Drop a selection that no longer points at a live bomb (sold, merged, resized).
	var has_selection := (
		_selected_slot >= 0
		and _selected_slot < GameState.slot_count
		and GameState.slots[_selected_slot] > 0
	)
	if not has_selection and _selected_slot >= 0:
		_selected_slot = -1
		if world != null:
			world.hide_slot_highlight()
	sell_button.disabled = not has_selection or _is_dragging or _is_animating
	var variation := &"OrangeButton" if has_selection else &"SmallButton"
	if sell_button.theme_type_variation != variation:
		sell_button.theme_type_variation = variation
	var hint := MERGE_HINT
	var hint_color := Color("#B8C2D8")
	if has_selection:
		hint = "SELECTED BOMB • SELLS FOR +$" + Economy.format_number(_sell_value(GameState.slots[_selected_slot]))
		hint_color = Color("#FFC83D")
	if merge_hint.text != hint:
		merge_hint.text = hint
		merge_hint.add_theme_color_override("font_color", hint_color)


func _format_time(seconds_left: float) -> String:
	var total := int(maxf(ceil(seconds_left), 0.0))
	return "%d:%02d" % [total / 60, total % 60]


func _update_event_banner() -> void:
	var event_data := EventManager.active_event
	if event_data is Dictionary and not event_data.is_empty():
		var bonus := int(round(float(event_data.get("income_bonus", 0.0)) * 100.0))
		event_banner.text = "%s  •  +%d%% INCOME" % [str(event_data.get("name", "EVENT")), bonus]
		event_banner.get_parent().visible = true
	else:
		event_banner.get_parent().visible = false


# --- Retention popups -------------------------------------------------------

func _show_tutorial_step() -> void:
	if _tutorial_step < TUTORIAL_STEPS.size():
		tutorial_label.text = TUTORIAL_STEPS[_tutorial_step]
		tutorial_popup.visible = true
	else:
		tutorial_popup.visible = false
		GameState.tutorial_completed = true
		SaveManager.save()
		_check_pending_popups()


func _on_tutorial_next() -> void:
	_tutorial_step += 1
	_show_tutorial_step()


func _on_daily_reward_available(day: int, amount: float) -> void:
	_pending_daily = {"day": day, "amount": amount}
	if tutorial_popup.visible or offline_popup.visible or _daily_popup_shown:
		return
	_show_daily(day, amount)


func _check_pending_popups() -> void:
	if not GameState.tutorial_completed:
		return
	if SaveManager.pending_offline > 0.0 and not offline_popup.visible:
		_show_offline()
		return
	if offline_popup.visible:
		return
	_check_pending_daily()


func _on_offline_ready(amount: float) -> void:
	if amount <= 0.0:
		return
	if not GameState.tutorial_completed:
		return
	_show_offline()


func _show_offline() -> void:
	if SaveManager.pending_offline <= 0.0:
		return
	offline_amount_label.text = "+$" + Economy.format_number(SaveManager.pending_offline)
	var duration := _format_duration(SaveManager.pending_offline_seconds)
	offline_time_label.text = "Your nukes worked for %s" % duration
	offline_popup.visible = true
	if daily_popup.visible:
		daily_popup.visible = false
		_daily_popup_shown = false


func _on_claim_offline_x2() -> void:
	AdService.show_rewarded_ad()
	_claim_offline(2)


func _claim_offline(multiplier: int) -> void:
	var amount := SaveManager.pending_offline
	offline_popup.visible = false
	if amount <= 0.0:
		_check_pending_popups()
		return
	GameState.add_cash(amount * float(multiplier))
	SaveManager.pending_offline = 0.0
	SaveManager.pending_offline_seconds = 0.0
	SaveManager.save()
	GameState.cash_changed.emit(GameState.cash)
	_update_hud()
	AudioManager.play_sfx("claim")
	_check_pending_popups()


func _format_duration(seconds: float) -> String:
	var total := int(maxf(seconds, 0.0))
	if total >= 3600:
		return "%dh %dm" % [total / 3600, (total % 3600) / 60]
	if total >= 60:
		return "%dm" % [total / 60]
	return "%ds" % total


func _check_pending_daily() -> void:
	if _daily_popup_shown or daily_popup.visible or tutorial_popup.visible or offline_popup.visible:
		return
	if not GameState.tutorial_completed:
		return
	var today := Time.get_date_string_from_system()
	if GameState.daily_claimed_date == today:
		return
	var day := maxi(GameState.daily_streak, 1)
	var amount := 100.0
	if not _pending_daily.is_empty():
		day = int(_pending_daily.get("day", day))
		amount = float(_pending_daily.get("amount", amount))
	else:
		amount = DailyRewardManager.get_reward_amount(day)
	_show_daily(day, amount)


func _show_daily(day: int, amount: float) -> void:
	_pending_daily = {"day": day, "amount": amount}
	daily_day_label.text = "DAY %d STREAK" % day
	daily_amount_label.text = "+$" + Economy.format_number(amount)
	daily_popup.visible = true
	_daily_popup_shown = true


func _on_claim_daily() -> void:
	DailyRewardManager.claim()
	daily_popup.visible = false
	GameState.cash_changed.emit(GameState.cash)
	_update_hud()


# --- Auto spawn -------------------------------------------------------------

func _on_auto_spawn() -> void:
	if _is_dragging or _is_animating:
		return
	if tutorial_popup.visible or daily_popup.visible or offline_popup.visible:
		return
	_suppress_slot_refresh = true
	# Spawn Tier upgrade raises free-spawn tier; cap at 99 so tier 100 stays a merge reward.
	var spawn_tier := clampi(1 + Economy.spawn_tier_level, 1, 99)
	var index := GameState.spawn_free(spawn_tier)
	_suppress_slot_refresh = false
	if index >= 0:
		_create_bomb(index, spawn_tier, true)
		_update_hud()
