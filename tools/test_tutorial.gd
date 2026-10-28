extends Node

## Dev-only tutorial popup screenshot/check.
## godot --headless --path . tools/test_tutorial.tscn

var _failures: int = 0


func _ready() -> void:
	GameState.tutorial_completed = false
	SaveManager.pending_offline = 0.0
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
	var popup := base.get("tutorial_popup") as Control
	_check(popup.visible, "tutorial: popup visible")
	_check((base.get("tutorial_label") as Label).text.length() > 10, "tutorial: step text populated")
	if DisplayServer.get_name() != "headless":
		var image := get_viewport().get_texture().get_image()
		if image != null:
			image.save_png("user://step8_tutorial.png")
	GameState.tutorial_completed = true
	if _failures == 0:
		print("TUTORIAL TEST: PASS")
		get_tree().quit(0)
	else:
		print("TUTORIAL TEST: FAIL (%d)" % _failures)
		get_tree().quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok  ", label)
	else:
		_failures += 1
		push_error("  FAIL  " + label)
