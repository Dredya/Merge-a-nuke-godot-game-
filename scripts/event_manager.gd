extends Node

## Data-driven events.

signal event_changed(event_data: Dictionary)

const EVENTS_PATH := "res://data/events.json"

var events: Array = []
var active_event: Dictionary = {}


func _ready() -> void:
	_load_events()
	_update_active_event()


func _load_events() -> void:
	if not FileAccess.file_exists(EVENTS_PATH):
		return
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		events = parsed


func _update_active_event() -> void:
	var today := Time.get_date_string_from_system()
	active_event = {}
	for e in events:
		if not (e is Dictionary):
			continue
		var start := str(e.get("start_date", ""))
		var end := str(e.get("end_date", ""))
		if start <= today and today <= end:
			active_event = e
			break
	# Apply income bonus
	var bonus := float(active_event.get("income_bonus", 0.0))
	Economy.set_event_multiplier(1.0 + bonus)
	event_changed.emit(active_event)