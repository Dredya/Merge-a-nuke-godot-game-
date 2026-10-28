extends Node

## Autoload: versioned JSON save/load with atomic writes and offline earnings.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

signal offline_earnings_ready(amount: float)

var pending_offline: float = 0.0
var _last_save_time: float = 0.0
var _autosave_timer: Timer


func _ready() -> void:
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = 30.0
	_autosave_timer.autostart = true
	_autosave_timer.timeout.connect(save)
	add_child(_autosave_timer)
	load_save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
		_last_save_time = Time.get_unix_time_from_system()
	if what == NOTIFICATION_APPLICATION_RESUMED:
		_handle_resume()


func save() -> void:
	var data := {
		"version": SAVE_VERSION,
		"cash": GameState.cash,
		"slot_count": GameState.slot_count,
		"slots": GameState.slots,
		"upgrade_levels": Economy.upgrade_levels,
		"lock_until": GameState.lock_until,
		"lock_cooldown_until": GameState.lock_cooldown_until,
		"redeemed_codes": GameState.redeemed_codes,
		"daily_streak": GameState.daily_streak,
		"last_login_date": GameState.last_login_date,
		"daily_claimed_date": GameState.daily_claimed_date,
		"mission_progress": GameState.mission_progress,
		"mission_claimed": GameState.mission_claimed,
		"mission_last_reset_date": GameState.mission_last_reset_date,
		"tutorial_completed": GameState.tutorial_completed,
		"last_save_time": Time.get_unix_time_from_system(),
	}
	var json_text := JSON.stringify(data)
	var tmp_path := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_error("Failed to open temp save file")
		return
	f.store_string(json_text)
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("Failed to open user dir for save")
		return
	if dir.file_exists("save.json"):
		dir.remove("save.json")
	var err := dir.rename("save.json.tmp", "save.json")
	if err != OK:
		push_error("Failed to rename save file: %d" % err)
	_last_save_time = Time.get_unix_time_from_system()


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("Invalid save file format")
		return
	var data := parsed as Dictionary
	# Version check (simple migration placeholder).
	var version := int(data.get("version", 0))
	if version != SAVE_VERSION:
		# For now, still attempt load.
		pass
	GameState.cash = float(data.get("cash", 0.0))
	GameState.slot_count = GameState.MAX_SLOTS
	GameState.slots.resize(GameState.slot_count)
	var saved_slots: Variant = data.get("slots", [])
	var saved_size := 0
	if saved_slots is Array:
		saved_size = (saved_slots as Array).size()
		for i in range(min(saved_size, GameState.slots.size())):
			GameState.slots[i] = int((saved_slots as Array)[i])
	# Old six-slot saves are migrated into the fixed 4x3 board.
	for i in range(GameState.slots.size()):
		if i >= saved_size:
			GameState.slots[i] = 0
	# Upgrade levels
	var saved_upgrades: Variant = data.get("upgrade_levels", {})
	if saved_upgrades is Dictionary:
		for k in saved_upgrades.keys():
			Economy.upgrade_levels[str(k)] = int(saved_upgrades[k])
	Economy._recompute_multipliers()
	GameState.lock_until = float(data.get("lock_until", 0.0))
	GameState.lock_cooldown_until = float(data.get("lock_cooldown_until", 0.0))
	var rc: Variant = data.get("redeemed_codes", [])
	if rc is Array:
		GameState.redeemed_codes.clear()
		for c in rc:
			GameState.redeemed_codes.append(str(c))
	GameState.daily_streak = int(data.get("daily_streak", 0))
	GameState.last_login_date = str(data.get("last_login_date", ""))
	GameState.daily_claimed_date = str(data.get("daily_claimed_date", ""))
	var mp: Variant = data.get("mission_progress", {})
	if mp is Dictionary:
		GameState.mission_progress = (mp as Dictionary).duplicate()
	var mc: Variant = data.get("mission_claimed", {})
	if mc is Dictionary:
		GameState.mission_claimed = (mc as Dictionary).duplicate()
	GameState.mission_last_reset_date = str(data.get("mission_last_reset_date", ""))
	GameState.tutorial_completed = bool(data.get("tutorial_completed", false))
	GameState.cash_changed.emit(GameState.cash)
	GameState.slots_changed.emit()
	Economy.upgrades_loaded.emit()
	# Offline earnings
	var last_time := float(data.get("last_save_time", 0.0))
	if last_time > 0.0:
		var now := Time.get_unix_time_from_system()
		var elapsed := now - last_time
		var cap := Economy.offline_cap_hours * 3600.0
		if elapsed > cap:
			elapsed = cap
		if elapsed < 0.0:
			elapsed = 0.0
		var income := GameState.income_per_second_total() * Economy.income_multiplier
		var amount := elapsed * income
		if amount > 0.0:
			pending_offline = amount
			offline_earnings_ready.emit(amount)


func _handle_resume() -> void:
	if _last_save_time <= 0.0:
		_last_save_time = Time.get_unix_time_from_system()
		return
	var now := Time.get_unix_time_from_system()
	var elapsed := now - _last_save_time
	var cap := Economy.offline_cap_hours * 3600.0
	if elapsed > cap:
		elapsed = cap
	if elapsed < 0.0:
		elapsed = 0.0
	var income := GameState.income_per_second_total() * Economy.income_multiplier
	var amount := elapsed * income
	if amount > 0.0:
		pending_offline = amount
		offline_earnings_ready.emit(amount)
	_last_save_time = now