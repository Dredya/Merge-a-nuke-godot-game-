extends Node

## Mission tracking with daily reset.

signal mission_progress_changed(mission_id: String, progress: int)
signal missions_reset

const MISSIONS_PATH := "res://data/missions.json"

var missions: Array = []


func _ready() -> void:
	_load_missions()
	_reset_if_new_day()


func _load_missions() -> void:
	if not FileAccess.file_exists(MISSIONS_PATH):
		return
	var file := FileAccess.open(MISSIONS_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		missions = parsed
		for m in missions:
			if m is Dictionary:
				var id := str(m.get("id", ""))
				if not GameState.mission_progress.has(id):
					GameState.mission_progress[id] = 0
				if not GameState.mission_claimed.has(id):
					GameState.mission_claimed[id] = false


func _reset_if_new_day() -> void:
	var today := Time.get_date_string_from_system()
	if GameState.mission_last_reset_date == today:
		return
	GameState.mission_last_reset_date = today
	for m in missions:
		if m is Dictionary:
			var id := str(m.get("id", ""))
			GameState.mission_progress[id] = 0
			GameState.mission_claimed[id] = false
	missions_reset.emit()


func on_merge() -> void:
	_increment_type("merge", 1)


func on_raid() -> void:
	_increment_type("raid", 1)


func on_cash_earned(amount: float) -> void:
	_increment_type("earn", int(amount))


func _increment_type(mtype: String, amount: int) -> void:
	for m in missions:
		if not (m is Dictionary):
			continue
		if str(m.get("type", "")) != mtype:
			continue
		var id := str(m.get("id", ""))
		var target := int(m.get("target", 1))
		var current := int(GameState.mission_progress.get(id, 0))
		if current >= target:
			continue
		current = min(current + amount, target)
		GameState.mission_progress[id] = current
		mission_progress_changed.emit(id, current)
		# Autosave covers partial progress; only force a write on completion.
		if current >= target:
			SaveManager.save()


func claim(mission_id: String) -> bool:
	for m in missions:
		if not (m is Dictionary):
			continue
		if str(m.get("id", "")) != mission_id:
			continue
		var target := int(m.get("target", 1))
		var progress := int(GameState.mission_progress.get(mission_id, 0))
		if progress < target:
			return false
		if bool(GameState.mission_claimed.get(mission_id, false)):
			return false
		var reward := float(m.get("reward_cash", 0))
		GameState.add_cash(reward)
		GameState.mission_claimed[mission_id] = true
		SaveManager.save()
		return true
	return false


func get_missions() -> Array:
	return missions