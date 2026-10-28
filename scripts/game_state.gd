extends Node

## Autoload singleton holding global game state: cash, slots, and tier data.

const NukeTierScript = preload("res://scripts/nuke_tier.gd")

signal cash_changed(new_cash: float)
signal slots_changed

const TIER_DATA_PATH := "res://data/nuke_tiers.json"
const MAX_SLOTS := 12
const MAX_TIER := 100

var tiers: Array[NukeTierScript] = []
var cash: float = 0.0
var slot_count: int = MAX_SLOTS
var slots: Array[int] = []
var owned_nukes: Dictionary = {}
# Highest tier the player has ever owned; drives the raid target scale.
var highest_tier_reached: int = 0
var lock_until: float = 0.0
var lock_cooldown_until: float = 0.0
# Retention
var redeemed_codes: Array[String] = []
var daily_streak: int = 0
var last_login_date: String = ""
var daily_claimed_date: String = ""
var mission_progress: Dictionary = {}
var mission_claimed: Dictionary = {}
var mission_last_reset_date: String = ""
var tutorial_completed: bool = false


func _ready() -> void:
	_load_tiers()
	slots.resize(slot_count)
	for i in range(slot_count):
		slots[i] = 0
	owned_nukes.clear()


func _load_tiers() -> void:
	if not FileAccess.file_exists(TIER_DATA_PATH):
		push_error("Missing tier data: " + TIER_DATA_PATH)
		return
	var file := FileAccess.open(TIER_DATA_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Array):
		push_error("Invalid tier data format in " + TIER_DATA_PATH)
		return
	for entry in parsed:
		if not (entry is Dictionary):
			continue
		var t = NukeTierScript.new()
		t.tier = int(entry.get("tier", 0))
		t.name = str(entry.get("name", ""))
		t.color = Color.html(str(entry.get("color", "#ffffff")))
		t.color_secondary = Color.html(str(entry.get("color_secondary", entry.get("color", "#ffffff"))))
		t.color_accent = Color.html(str(entry.get("color_accent", entry.get("color", "#ffffff"))))
		t.glow_color = Color.html(str(entry.get("glow_color", entry.get("color", "#ffffff"))))
		t.income_per_sec = float(entry.get("income_per_sec", 0.0))
		t.build_id = str(entry.get("build_id", "classic"))
		tiers.append(t)


func get_tier(tier_number: int) -> NukeTierScript:
	for t in tiers:
		if t.tier == tier_number:
			return t
	return null


func add_cash(amount: float) -> void:
	cash += amount
	cash_changed.emit(cash)


func set_slot(index: int, tier_number: int) -> void:
	if index < 0 or index >= slots.size():
		return
	slots[index] = clampi(tier_number, 0, MAX_TIER)
	_note_tier(slots[index])
	slots_changed.emit()


func commit_slots(new_slots: Array[int]) -> void:
	## Replace the whole board in one notification (drag / merge operations).
	if new_slots.size() != slots.size():
		return
	for i in range(slots.size()):
		slots[i] = clampi(new_slots[i], 0, MAX_TIER)
		_note_tier(slots[i])
	slots_changed.emit()


func empty_slot_count() -> int:
	var count := 0
	for t in slots:
		if t <= 0:
			count += 1
	return count


func spawn_free(tier_number: int = 1) -> int:
	var tier := clampi(tier_number, 1, MAX_TIER)
	for i in range(slots.size()):
		if slots[i] == 0:
			slots[i] = tier
			slots_changed.emit()
			_track_owned(tier)
			return i
	return -1


func income_per_second_total() -> float:
	var total := 0.0
	for slot_tier in slots:
		if slot_tier > 0:
			var t: NukeTierScript = get_tier(slot_tier)
			if t != null:
				total += t.income_per_sec
	return total


func _track_owned(tier_number: int) -> void:
	owned_nukes[tier_number] = int(owned_nukes.get(tier_number, 0)) + 1
	_note_tier(tier_number)


func _note_tier(tier_number: int) -> void:
	if tier_number > highest_tier_reached:
		highest_tier_reached = tier_number