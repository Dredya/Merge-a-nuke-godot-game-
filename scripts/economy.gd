extends Node

## Autoload: cash flow, income, upgrades, and number formatting.

const UPGRADES_PATH := "res://data/upgrades.json"

signal income_granted(amount: float)
signal upgrade_purchased(upgrade_id: String)
signal upgrades_loaded

var upgrades: Array = []
var upgrade_levels: Dictionary = {}
var income_multiplier: float = 1.0
var event_income_multiplier: float = 1.0
var spawn_speed_level: int = 0
var offline_cap_hours: float = 8.0

var _income_timer: Timer


func _ready() -> void:
	_load_upgrades()
	_income_timer = Timer.new()
	_income_timer.wait_time = 1.0
	_income_timer.autostart = true
	_income_timer.timeout.connect(_on_income_tick)
	add_child(_income_timer)


func _load_upgrades() -> void:
	if not FileAccess.file_exists(UPGRADES_PATH):
		push_error("Missing upgrades data: " + UPGRADES_PATH)
		return
	var file := FileAccess.open(UPGRADES_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		upgrades = parsed
		for u in upgrades:
			if u is Dictionary:
				upgrade_levels[str(u.get("id", ""))] = 0
	upgrades_loaded.emit()
	_recompute_multipliers()


func get_upgrade(id: String) -> Dictionary:
	for u in upgrades:
		if u is Dictionary and str(u.get("id", "")) == id:
			return u
	return {}


func get_upgrade_level(id: String) -> int:
	return int(upgrade_levels.get(id, 0))


func get_upgrade_cost(id: String) -> int:
	var u := get_upgrade(id)
	if u.is_empty():
		return 0
	var base_cost := int(u.get("base_cost", 0))
	var scale := float(u.get("cost_scale", 1.0))
	var level := get_upgrade_level(id)
	return int(float(base_cost) * pow(scale, float(level)))


func can_buy_upgrade(id: String) -> bool:
	var u := get_upgrade(id)
	if u.is_empty():
		return false
	var level := get_upgrade_level(id)
	var max_level := int(u.get("max_level", 999))
	if level >= max_level:
		return false
	var cost := get_upgrade_cost(id)
	return GameState.cash >= float(cost)


func buy_upgrade(id: String) -> bool:
	if not can_buy_upgrade(id):
		return false
	var u := get_upgrade(id)
	var cost := get_upgrade_cost(id)
	GameState.cash -= float(cost)
	GameState.cash_changed.emit(GameState.cash)
	upgrade_levels[id] = get_upgrade_level(id) + 1
	_apply_upgrade_effect(id, u)
	upgrade_purchased.emit(id)
	SaveManager.save()
	return true


func _apply_upgrade_effect(id: String, u: Dictionary) -> void:
	var effect := float(u.get("effect_per_level", 0.0))
	match id:
		"slot_count":
			GameState.slot_count += int(effect)
		"spawn_speed":
			spawn_speed_level = get_upgrade_level(id)
		"income_multiplier":
			_recompute_multipliers()
		"offline_cap":
			offline_cap_hours = 8.0 + float(get_upgrade_level(id)) * effect
	_recompute_multipliers()


func _recompute_multipliers() -> void:
	var mult := 1.0
	var level := get_upgrade_level("income_multiplier")
	var u := get_upgrade("income_multiplier")
	var effect := float(u.get("effect_per_level", 0.1)) if not u.is_empty() else 0.1
	mult += float(level) * effect
	income_multiplier = mult
	# spawn speed level
	spawn_speed_level = get_upgrade_level("spawn_speed")
	# offline cap
	var ou := get_upgrade("offline_cap")
	var oeffect := float(ou.get("effect_per_level", 2.0)) if not ou.is_empty() else 2.0
	offline_cap_hours = 8.0 + float(get_upgrade_level("offline_cap")) * oeffect


func _on_income_tick() -> void:
	var income := GameState.income_per_second_total() * income_multiplier * event_income_multiplier
	if income > 0.0:
		GameState.add_cash(income)
		income_granted.emit(income)
		var mm = get_node_or_null("/root/MissionManager")
		if mm != null:
			mm.on_cash_earned(income)


func format_number(value: float) -> String:
	var suffixes := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
	var v := value
	var idx := 0
	while v >= 1000.0 and idx < suffixes.size() - 1:
		v /= 1000.0
		idx += 1
	if idx == 0:
		return str(int(v))
	if v < 10.0:
		return "%.2f%s" % [v, suffixes[idx]]
	if v < 100.0:
		return "%.1f%s" % [v, suffixes[idx]]
	return "%.0f%s" % [v, suffixes[idx]]


func set_event_multiplier(value: float) -> void:
	event_income_multiplier = value