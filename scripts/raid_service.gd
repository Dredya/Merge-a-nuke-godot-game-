extends Node

## Raid service interface. Current implementation is AI-only; real multiplayer
## can replace this autoload later.

signal targets_refreshed
signal player_raided(amount: float)

const REFRESH_INTERVAL := 120.0
const AI_RAID_INTERVAL := 60.0
const AI_NAMES := [
	"Cinder Keep", "Neon Vault", "Rustbucket", "Mega Mine", "Sky Fort",
	"Boom Bunker", "Toxic Depot", "Iron Yard", "Glow Peak", "Nuke Nest",
]

var targets: Array = []
var _refresh_timer: Timer
var _ai_raid_timer: Timer


func _ready() -> void:
	_generate_targets()
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = REFRESH_INTERVAL
	_refresh_timer.autostart = true
	_refresh_timer.timeout.connect(_on_refresh)
	add_child(_refresh_timer)
	_ai_raid_timer = Timer.new()
	_ai_raid_timer.wait_time = AI_RAID_INTERVAL
	_ai_raid_timer.autostart = true
	_ai_raid_timer.timeout.connect(_on_ai_raid_tick)
	add_child(_ai_raid_timer)


func get_targets() -> Array:
	return targets


func _on_refresh() -> void:
	# Keep revenge targets, regenerate the rest.
	var revenge: Array = []
	for t in targets:
		if t is Dictionary and bool(t.get("is_revenge", false)):
			revenge.append(t)
	_generate_targets()
	for r in revenge:
		targets.append(r)
	targets_refreshed.emit()


func _generate_targets() -> void:
	targets.clear()
	# Loot scales with the player's economy so raids stay relevant.
	var base_loot := maxf(1500.0, GameState.cash * 4.0 + GameState.income_per_second_total() * 90.0)
	var count := randi_range(5, 8)
	var name_offset := randi_range(0, AI_NAMES.size() - 1)
	for i in range(count):
		targets.append({
			"id": "base_%d_%d" % [Time.get_ticks_msec(), i],
			"name": str(AI_NAMES[(name_offset + i) % AI_NAMES.size()]),
			"cash": base_loot * randf_range(0.45, 1.6),
			# Always show at least one locked target for the raid list design.
			"locked": i == 1 or randf() < 0.25,
			"cooldown_until": 0.0,
			"is_revenge": false,
		})


func _on_ai_raid_tick() -> void:
	var now := Time.get_unix_time_from_system()
	if now < GameState.lock_until:
		return
	if GameState.cash <= 0.0:
		return
	if randf() > 0.35:
		return
	var stolen := GameState.cash * 0.05
	if stolen < 1.0:
		stolen = 1.0
	GameState.cash -= stolen
	GameState.cash_changed.emit(GameState.cash)
	targets.append({
		"id": "rev_%d" % targets.size(),
		"name": "Revenge Base",
		"cash": stolen * 2.0,
		"locked": false,
		"cooldown_until": 0.0,
		"is_revenge": true,
	})
	player_raided.emit(stolen)
	targets_refreshed.emit()