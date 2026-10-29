extends Node

## Autoload: versioned JSON save/load with atomic writes and offline earnings.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const MIN_OFFLINE_SECONDS := 60.0

signal offline_earnings_ready(amount: float)

var pending_offline: float = 0.0
var pending_offline_seconds: float = 0.0
var _last_save_time: float = 0.0
var _autosave_accum: float = 0.0
const AUTOSAVE_INTERVAL := 15.0


func _ready() -> void:
	_autosave_accum = 0.0
	load_save()


func _process(delta: float) -> void:
	# Frame-accumulated autosave so it cannot stall the way a Timer can.
	_autosave_accum += delta
	if _autosave_accum >= AUTOSAVE_INTERVAL:
		_autosave_accum = 0.0
		save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
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
		"highest_tier_reached": GameState.highest_tier_reached,
		"upgrade_levels": Economy.upgrade_levels,
		"lock_until": GameState.lock_until,
		"lock_cooldown_until": GameState.lock_cooldown_until,
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
	# Write to a temp file first, verify it, then atomically promote it.
	var tmp_path := "user://save.json.tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_error("Failed to open temp save file")
		# Fall back to a direct write so progress is never lost.
		_write_direct(json_text)
		_last_save_time = Time.get_unix_time_from_system()
		return
	f.store_string(json_text)
	f.close()
	# Verify the temp file is readable and non-empty.
	var check := FileAccess.open(tmp_path, FileAccess.READ)
	if check == null or check.get_length() <= 0:
		push_error("Temp save file is empty or unreadable")
		if check != null:
			check.close()
		_write_direct(json_text)
		_last_save_time = Time.get_unix_time_from_system()
		return
	check.close()
	# Keep a backup of the previous save before promoting.
	var dir := DirAccess.open("user://")
	if dir != null:
		if dir.file_exists("save.json"):
			# Copy current save to .bak (best-effort).
			var old_file := FileAccess.open("user://save.json", FileAccess.READ)
			if old_file != null:
				var old_text := old_file.get_as_text()
				old_file.close()
				var bak := FileAccess.open("user://save.json.bak", FileAccess.WRITE)
				if bak != null:
					bak.store_string(old_text)
					bak.close()
		# Promote tmp -> save. Remove destination first (some platforms require it).
		if dir.file_exists("save.json"):
			dir.remove("save.json")
		var err := dir.rename("save.json.tmp", "save.json")
		if err != OK:
			push_error("Failed to rename save file: %d" % err)
			_write_direct(json_text)
	# Clean up the temp file if it still exists.
	if dir != null and dir.file_exists("save.json.tmp"):
		dir.remove("save.json.tmp")
	_last_save_time = Time.get_unix_time_from_system()


func _write_direct(json_text: String) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Failed to open save file for direct write")
		return
	f.store_string(json_text)
	f.close()


func load_save() -> void:
	# Pick the best available save between save.json and save.json.bak so a
	# stranded backup (with more progress) is never ignored.
	var candidates: Array[String] = []
	if FileAccess.file_exists(SAVE_PATH):
		candidates.append(SAVE_PATH)
	if FileAccess.file_exists("user://save.json.bak"):
		candidates.append("user://save.json.bak")
	if candidates.is_empty():
		return
	var best_path := candidates[0]
	var best_score := -1.0
	var best_time := 0.0
	for cpath in candidates:
		var cf := FileAccess.open(cpath, FileAccess.READ)
		if cf == null:
			continue
		var ctext := cf.get_as_text()
		cf.close()
		var cparsed: Variant = JSON.parse_string(ctext)
		if not (cparsed is Dictionary):
			continue
		var cd := cparsed as Dictionary
		var ccash := float(cd.get("cash", 0.0))
		var ctier := int(cd.get("highest_tier_reached", 0))
		var ctime := float(cd.get("last_save_time", 0.0))
		var score := float(ctier) * 1000000000.0 + ccash
		if score > best_score or (score == best_score and ctime > best_time):
			best_score = score
			best_time = ctime
			best_path = cpath
	var path := best_path
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		# Last resort: try the backup.
		if path != "user://save.json.bak" and FileAccess.file_exists("user://save.json.bak"):
			file = FileAccess.open("user://save.json.bak", FileAccess.READ)
		if file == null:
			return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		# Try backup on corrupt primary.
		if path != "user://save.json.bak" and FileAccess.file_exists("user://save.json.bak"):
			var bak_file := FileAccess.open("user://save.json.bak", FileAccess.READ)
			if bak_file != null:
				var bak_text := bak_file.get_as_text()
				bak_file.close()
				var bak_parsed: Variant = JSON.parse_string(bak_text)
				if bak_parsed is Dictionary:
					parsed = bak_parsed
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
	var saved_slot_count := int(data.get("slot_count", 6))
	GameState.slot_count = clampi(saved_slot_count, 6, GameState.MAX_SLOTS)
	GameState.slots.resize(GameState.slot_count)
	var saved_slots: Variant = data.get("slots", [])
	var saved_size := 0
	if saved_slots is Array:
		saved_size = (saved_slots as Array).size()
		for i in range(min(saved_size, GameState.slots.size())):
			GameState.slots[i] = clampi(int((saved_slots as Array)[i]), 0, GameState.MAX_TIER)
	GameState.highest_tier_reached = int(data.get("highest_tier_reached", 0))
	for slot_tier in GameState.slots:
		GameState.highest_tier_reached = maxi(GameState.highest_tier_reached, slot_tier)
	# Old saves with fewer slots are migrated into the current board.
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
	# Restore the last save time so resume/offline earnings work.
	var last_time := float(data.get("last_save_time", 0.0))
	if last_time > 0.0:
		_last_save_time = last_time
	# Offline earnings
	if last_time > 0.0:
		var now := Time.get_unix_time_from_system()
		var elapsed := now - last_time
		var cap := Economy.offline_cap_hours * 3600.0
		if elapsed > cap:
			elapsed = cap
		if elapsed < 0.0:
			elapsed = 0.0
		var income := GameState.income_per_second_total() * Economy.event_income_multiplier
		var amount := elapsed * income
		if elapsed >= MIN_OFFLINE_SECONDS and amount > 0.0:
			pending_offline = amount
			pending_offline_seconds = elapsed
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
	var income := GameState.income_per_second_total() * Economy.event_income_multiplier
	var amount := elapsed * income
	if elapsed >= MIN_OFFLINE_SECONDS and amount > 0.0:
		pending_offline = amount
		pending_offline_seconds = elapsed
		offline_earnings_ready.emit(amount)
	_last_save_time = now