extends Node

## Autoload singleton holding global game state: cash, slots, and tier data.

const NukeTierScript = preload("res://scripts/nuke_tier.gd")

signal cash_changed(new_cash: float)
signal slots_changed

const TIER_DATA_PATH := "res://data/nuke_tiers.json"

var tiers: Array[NukeTierScript] = []
var cash: float = 0.0
var slot_count: int = 6
var slots: Array[int] = []
var owned_nukes: Dictionary = {}
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
		t.income_per_sec = float(entry.get("income_per_sec", 0.0))
		t.buy_cost = int(entry.get("buy_cost", 0))
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
	slots[index] = tier_number
	slots_changed.emit()


func try_buy_tier1() -> bool:
	var t: NukeTierScript = get_tier(1)
	if t == null:
		return false
	if cash < float(t.buy_cost):
		return false
	for i in range(slots.size()):
		if slots[i] == 0:
			cash -= float(t.buy_cost)
			cash_changed.emit(cash)
			set_slot(i, 1)
			_track_owned(1)
			return true
	return false


func spawn_tier1_free() -> bool:
	for i in range(slots.size()):
		if slots[i] == 0:
			set_slot(i, 1)
			_track_owned(1)
			return true
	return false


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