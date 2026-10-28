extends Node

## Dev-only integration test for the raid screen and 3D launch animation.
## Run: godot --headless --path . tools/test_raid.tscn

var _failures: int = 0
var _had_save: bool = false
var _save_text: String = ""


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		get_tree().quit(1)
		return
	add_child(packed.instantiate())
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var main := find_child("Main", true, false)
	if main == null:
		push_error("Main not found")
		get_tree().quit(1)
		return
	# Inject a revenge target so the gold REVENGE section is exercised visually.
	RaidService.targets.append({
		"id": "rev_test",
		"name": "Revenge Base",
		"cash": 5000.0,
		"locked": false,
		"cooldown_until": 0.0,
		"is_revenge": true,
	})
	main.call("show_screen", "raid")
	await get_tree().process_frame
	await get_tree().process_frame
	var raid := get_tree().root.find_child("RaidScreen", true, false)
	if raid == null:
		push_error("RaidScreen not found")
		get_tree().quit(1)
		return

	_had_save = FileAccess.file_exists("user://save.json")
	if _had_save:
		var file := FileAccess.open("user://save.json", FileAccess.READ)
		if file != null:
			_save_text = file.get_as_text()
			file.close()

	var target: Dictionary = {}
	for entry in RaidService.get_targets():
		if entry is Dictionary and not bool(entry.get("locked", false)):
			target = entry.duplicate()
			break
	if target.is_empty():
		push_error("No unlocked raid target")
		_restore_save()
		get_tree().quit(1)
		return

	var cash_before := GameState.cash
	var expected := maxf(float(target.get("cash", 0.0)) * 0.2, 1.0)
	await raid.call("_on_launch", target)
	await get_tree().create_timer(0.2).timeout
	_check(GameState.cash >= cash_before + expected - 0.01, "raid: cash granted")
	_check((raid.get("result_popup") as Control).visible, "raid: result popup visible")
	var cooldown_ok := false
	for entry in RaidService.targets:
		if entry is Dictionary and str(entry.get("id", "")) == str(target.get("id", "")):
			cooldown_ok = float(entry.get("cooldown_until", 0.0)) > Time.get_unix_time_from_system()
	_check(cooldown_ok, "raid: target cooldown applied")

	if DisplayServer.get_name() != "headless":
		var image := get_viewport().get_texture().get_image()
		if image != null:
			image.save_png("user://step6_raid.png")
		(raid.call("_close_result"))
		await get_tree().create_timer(0.25).timeout
		var list_image := get_viewport().get_texture().get_image()
		if list_image != null:
			list_image.save_png("user://step6_raid_list.png")

	_restore_save()
	if _failures == 0:
		print("RAID TEST: PASS")
		get_tree().quit(0)
	else:
		print("RAID TEST: FAIL (%d)" % _failures)
		get_tree().quit(1)


func _restore_save() -> void:
	if _had_save:
		var file := FileAccess.open("user://save.json", FileAccess.WRITE)
		if file != null:
			file.store_string(_save_text)
			file.close()
	else:
		var dir := DirAccess.open("user://")
		if dir != null and dir.file_exists("save.json"):
			dir.remove("save.json")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok  ", label)
	else:
		_failures += 1
		push_error("  FAIL  " + label)
