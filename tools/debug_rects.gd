extends SceneTree

## Dev-only debug helper: dump layout rects of key base-screen nodes.
## godot --path . --resolution 540x960 --script tools/debug_rects.gd

var _frames: int = 0


func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed != null:
		root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 40:
		return false
	var main := root.get_node_or_null("Main")
	if main == null:
		quit()
		return true
	var base := (main as Control).get_node_or_null("SafeArea/Shell/ScreenContainer/BaseScreen")
	if base == null:
		print("BaseScreen missing; children of ScreenContainer:")
		var sc := main.get_node("SafeArea/Shell/ScreenContainer")
		for c in sc.get_children():
			print("  ", c.name)
		quit()
		return true
	for path in [
		".",
		"VBox",
		"VBox/TopHud",
		"VBox/TopHud/HudRow",
		"VBox/TopHud/HudRow/CashPanel",
		"VBox/TopHud/HudRow/CashPanel/CashBox/CashAmount",
		"VBox/Middle",
		"VBox/Middle/WorldView",
		"VBox/BottomControls",
	]:
		var n := base.get_node_or_null(path)
		if n is Control:
			var c := n as Control
			print(path, " visible=", c.visible, " rect=", c.get_rect(), " min=", c.get_combined_minimum_size())
		else:
			print(path, " MISSING")
	print("viewport=", root.get_visible_rect().size)
	quit()
	return true
