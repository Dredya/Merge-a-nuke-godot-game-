extends SceneTree

## Dev-only screenshot helper:
## godot --path . --script tools/capture.gd -- <scene path> <output png>

var _frames: int = 0
var _scene_path: String = "res://scenes/main.tscn"
var _output_path: String = "user://capture.png"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_scene_path = args[0]
	if args.size() > 1:
		_output_path = args[1]
	var packed: PackedScene = load(_scene_path)
	if packed != null:
		root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 45:
		return false
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png(_output_path)
		print("Saved capture: ", _output_path)
	quit()
	return true
