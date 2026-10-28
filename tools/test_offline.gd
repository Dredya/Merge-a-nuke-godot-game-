extends Node

## Dev-only test for the offline earnings popup and x2 claim.
## Run: godot --headless --path . tools/test_offline.tscn

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
	await get_tree().process_frame
	var base := get_tree().root.find_child("BaseScreen", true, false)
	if base == null:
		push_error("BaseScreen not found")
		get_tree().quit(1)
		return

	_had_save = FileAccess.file_exists("user://save.json")
	if _had_save:
		var file := FileAccess.open("user://save.json", FileAccess.READ)
		if file != null:
			_save_text = file.get_as_text()
			file.close()

	GameState.tutorial_completed = true
	(base.get("tutorial_popup") as Control).visible = false
	(base.get("daily_popup") as Control).visible = false
	SaveManager.pending_offline = 2400000.0
	SaveManager.pending_offline_seconds = 18720.0
	base.call("_show_offline")
	await get_tree().process_frame

	var popup := base.get("offline_popup") as Control
	var amount := base.get("offline_amount_label") as Label
	var time_label := base.get("offline_time_label") as Label
	_check(popup.visible, "offline: popup visible")
	_check(amount.text.contains("2.4M"), "offline: amount formatted as +$2.4M")
	_check(time_label.text.contains("5h 12m"), "offline: duration formatted as 5h 12m")

	if DisplayServer.get_name() != "headless":
		var image := get_viewport().get_texture().get_image()
		if image != null:
			image.save_png("user://step7_offline.png")

	var cash_before := GameState.cash
	base.call("_on_claim_offline_x2")
	await get_tree().process_frame
	_check(absf(GameState.cash - (cash_before + 4800000.0)) < 0.5, "offline: x2 claim added $4.8M")
	_check(not popup.visible, "offline: popup closed")
	_check(SaveManager.pending_offline == 0.0, "offline: pending cleared")

	_restore_save()
	if _failures == 0:
		print("OFFLINE TEST: PASS")
		get_tree().quit(0)
	else:
		print("OFFLINE TEST: FAIL (%d)" % _failures)
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
