extends Node

## Dev-only integration test for the 3D drag / merge / swap flow.
## Run: godot --headless --path . tools/test_merge.tscn

var _failures: int = 0
var _base: Control
var _had_save: bool = false
var _save_text: String = ""


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		push_error("Missing main scene")
		get_tree().quit(1)
		return
	add_child(packed.instantiate())
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_base = get_tree().root.find_child("BaseScreen", true, false) as Control
	if _base == null:
		push_error("BaseScreen not found")
		get_tree().quit(1)
		return
	_had_save = FileAccess.file_exists("user://save.json")
	if _had_save:
		var f := FileAccess.open("user://save.json", FileAccess.READ)
		if f != null:
			_save_text = f.get_as_text()
			f.close()

	# Deterministic board: bomb at 0, bomb at 1, bomb at 2.
	for i in range(GameState.MAX_SLOTS):
		GameState.slots[i] = 0
	GameState.slots[0] = 1
	GameState.slots[1] = 2
	GameState.slots[2] = 1
	_base.call("_refresh_all_slots")
	await get_tree().create_timer(0.25).timeout

	# 1. Move 0 -> 3.
	await _drag(0, 3)
	_check(GameState.slots[3] == 1, "move: slot 3 has tier 1")
	_check(GameState.slots[0] == 0, "move: slot 0 emptied")

	# 2. Merge 3 (tier 1) into 2 (tier 1) -> tier 2.
	await _drag(3, 2)
	_check(GameState.slots[2] == 2, "merge: slot 2 became tier 2")
	_check(GameState.slots[3] == 0, "merge: slot 3 emptied")
	var bombs: Array = _base.get("slot_bombs")
	_check(bombs[2] != null, "merge: new bomb visual exists")

	# 3. Swap two different tiers.
	GameState.slots[0] = 3
	GameState.slots[1] = 2
	GameState.slots[2] = 0
	_base.call("_refresh_all_slots")
	await get_tree().create_timer(0.25).timeout
	await _drag(0, 1)
	_check(GameState.slots[0] == 2, "swap: slot 0 holds old slot 1 tier")
	_check(GameState.slots[1] == 3, "swap: slot 1 holds old slot 0 tier")

	# 4. Buy button spends cash and fills the first empty slot.
	for i in range(GameState.MAX_SLOTS):
		GameState.slots[i] = 0
	GameState.cash = 1000.0
	GameState.cash_changed.emit(GameState.cash)
	_base.call("_refresh_all_slots")
	await get_tree().create_timer(0.2).timeout
	var buy_button := _base.get("buy_button") as Button
	buy_button.emit_signal("pressed")
	await get_tree().process_frame
	_check(GameState.cash == 880.0, "buy: cost $120 deducted")
	_check(GameState.slots[0] == 1, "buy: tier 1 placed in first empty slot")

	# 5. Lock button spends cash and starts the shield countdown.
	GameState.lock_until = 0.0
	GameState.lock_cooldown_until = 0.0
	var lock_button := _base.get("lock_button") as Button
	lock_button.emit_signal("pressed")
	await get_tree().process_frame
	_check(GameState.lock_until > Time.get_unix_time_from_system(), "lock: shield countdown started")
	_check(GameState.cash == 380.0, "lock: $500 deducted")

	if DisplayServer.get_name() != "headless":
		# Visual QA snapshot of a full board.
		(_base.get("tutorial_popup") as Control).visible = false
		(_base.get("daily_popup") as Control).visible = false
		GameState.cash = 28800.0
		GameState.cash_changed.emit(GameState.cash)
		for i in range(GameState.MAX_SLOTS):
			GameState.slots[i] = i + 1
		_base.call("_refresh_all_slots")
		await get_tree().create_timer(0.8).timeout
		var board_image := get_viewport().get_texture().get_image()
		if board_image != null:
			board_image.save_png("user://step4_board.png")
		# Snapshot mid merge effect.
		for i in range(GameState.MAX_SLOTS):
			GameState.slots[i] = 0
		GameState.slots[0] = 1
		GameState.slots[1] = 1
		_base.call("_refresh_all_slots")
		await get_tree().create_timer(0.3).timeout
		_base.set("_drag_from", 0)
		_base.set("_drag_tier", 1)
		_base.set("_drag_bomb", (_base.get("slot_bombs") as Array)[0])
		(_base.get("slot_bombs") as Array)[0] = null
		_base.call("_merge_into", 1)
		await get_tree().create_timer(0.18).timeout
		var fx_image := get_viewport().get_texture().get_image()
		if fx_image != null:
			fx_image.save_png("user://step4_merge.png")
		await get_tree().create_timer(1.0).timeout

	if _had_save:
		var f := FileAccess.open("user://save.json", FileAccess.WRITE)
		if f != null:
			f.store_string(_save_text)
			f.close()
	else:
		var dir := DirAccess.open("user://")
		if dir != null and dir.file_exists("save.json"):
			dir.remove("save.json")

	if _failures == 0:
		print("MERGE TEST: PASS")
		get_tree().quit(0)
	else:
		print("MERGE TEST: FAIL (%d)" % _failures)
		get_tree().quit(1)


func _drag(from_slot: int, to_slot: int) -> void:
	var from_pos: Vector2 = _local_for_slot(from_slot)
	var to_pos: Vector2 = _local_for_slot(to_slot)
	_base.call("_try_start_drag", from_pos)
	await get_tree().process_frame
	_base.call("_move_drag", to_pos)
	await get_tree().process_frame
	_base.call("_finish_drag", to_pos)
	await get_tree().create_timer(0.9).timeout


func _local_for_slot(slot: int) -> Vector2:
	var world: BaseWorld = _base.get("world") as BaseWorld
	var camera := world.camera
	var viewport_size: Vector2i = (_base.get("sub_viewport") as SubViewport).size
	var container_size: Vector2 = (_base.get("world_view") as SubViewportContainer).size
	var world_pos := world.slot_position(slot)
	var viewport_pos := camera.unproject_position(world_pos)
	return Vector2(
		viewport_pos.x / float(viewport_size.x) * container_size.x,
		viewport_pos.y / float(viewport_size.y) * container_size.y
	)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok  ", label)
	else:
		_failures += 1
		push_error("  FAIL  " + label)
