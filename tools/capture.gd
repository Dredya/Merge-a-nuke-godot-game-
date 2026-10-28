extends SceneTree

## Dev-only screenshot helper:
## godot --path . --script tools/capture.gd -- <scene path> <output png>

var _frames: int = 0
var _scene_path: String = "res://scenes/main.tscn"
var _output_path: String = "user://capture.png"
var _switch_screen: String = ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_scene_path = args[0]
	if args.size() > 1:
		_output_path = args[1]
	if args.size() > 2:
		_switch_screen = args[2]
	var packed: PackedScene = load(_scene_path)
	if packed != null:
		root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 20 and not _switch_screen.is_empty():
		var main := root.get_node_or_null("Main")
		if main != null:
			main.call("show_screen", _switch_screen)
	if _frames < 55:
		return false
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png(_output_path)
		print("Saved capture: ", _output_path)
	quit()
	return true
