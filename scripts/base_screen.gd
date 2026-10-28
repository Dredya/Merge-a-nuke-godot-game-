extends Control

## Main gameplay screen: slot grid, buy/auto-spawn, drag-and-drop merging.

const NukeTierScript = preload("res://scripts/nuke_tier.gd")
const SLOT_SIZE := Vector2(100, 100)

@onready var cash_label: Label = $MarginContainer/VBoxContainer/CashLabel
@onready var slot_grid: GridContainer = $MarginContainer/VBoxContainer/SlotGrid
@onready var buy_button: Button = $MarginContainer/VBoxContainer/BuyBombButton
@onready var auto_timer: Timer = $AutoSpawnTimer
@onready var income_timer: Timer = $IncomeTimer

var slot_nodes: Array[Control] = []
var slot_nuke: Array[Control] = []
var slot_tier: Array[int] = []

var dragged_tier: int = 0
var dragged_from: int = -1
var drag_visual: Control = null
var is_dragging: bool = false


func _ready() -> void:
	_build_slots()
	buy_button.pressed.connect(_on_buy_pressed)
	auto_timer.timeout.connect(_on_auto_spawn)
	income_timer.timeout.connect(_on_income_tick)
	GameState.cash_changed.connect(_on_cash_changed)
	GameState.slots_changed.connect(_on_slots_changed)
	_on_cash_changed(GameState.cash)
	_refresh_all_slots()


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
	# Silent hook for sound playback.
	pass


func _on_merge_haptics() -> void:
	Input.vibrate_handheld(100)


func _on_buy_pressed() -> void:
	if GameState.try_buy_tier1():
		_refresh_all_slots()


func _on_auto_spawn() -> void:
	if GameState.spawn_tier1_free():
		_refresh_all_slots()


func _on_income_tick() -> void:
	var income := GameState.income_per_second_total()
	if income > 0.0:
		GameState.add_cash(income)
	_refresh_cash()


func _on_cash_changed(new_cash: float) -> void:
	cash_label.text = "Cash: %d" % int(new_cash)


func _on_slots_changed() -> void:
	_refresh_all_slots()


func _refresh_all_slots() -> void:
	for i in range(slot_nodes.size()):
		var tier_val: int = 0
		if i < GameState.slots.size():
			tier_val = GameState.slots[i]
		slot_tier[i] = tier_val
		_clear_slot_visual(i)
		if tier_val > 0:
			_place_nuke(i, tier_val)


func _refresh_cash() -> void:
	cash_label.text = "Cash: %d" % int(GameState.cash)