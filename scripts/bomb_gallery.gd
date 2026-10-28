extends Node3D

## Debug gallery: the bespoke 1-15 tiers plus milestone samples through 100.
## Run directly: godot --path . scenes/bomb_gallery.tscn
const LABEL_FONT := "res://assets/fonts/LilitaOne-Regular.ttf"
const COLS := 5
const SPACING_X := 2.8
const SPACING_Z := 2.6
const SHOWCASE := [
	1, 2, 3, 4, 5,
	6, 7, 8, 9, 10,
	11, 12, 13, 14, 15,
	16, 20, 25, 30, 35,
	40, 45, 50, 60, 70,
	75, 80, 90, 95, 100,
]


func _ready() -> void:
	add_child(LowPoly.create_environment(true))
	add_child(LowPoly.create_sun())
	_build_ground()
	_build_camera()
	_build_bombs()
	_build_overlay()


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.mesh = LowPoly.cylinder(18.0, 17.0, 1.2, 32, false)
	ground.material_override = LowPoly.material(Color("#9BE08A"), 0.0, 0.95)
	ground.position = Vector3(0.0, -1.2, 0.0)
	add_child(ground)
	var pad := MeshInstance3D.new()
	pad.mesh = LowPoly.box(Vector3(17.5, 0.16, 16.5))
	pad.material_override = LowPoly.material(Color("#4CAF50"), 0.0, 0.9)
	pad.position = Vector3(0.0, -0.56, 0.0)
	add_child(pad)


func _build_camera() -> void:
	var camera := LowPoly.create_camera(38.0)
	camera.position = Vector3(23.2, 23.0, 23.2)
	add_child(camera)


func _build_bombs() -> void:
	var rows := int(ceil(float(SHOWCASE.size()) / float(COLS)))
	for index in range(SHOWCASE.size()):
		var tier: int = SHOWCASE[index]
		var col := index % COLS
		var row := index / COLS
		var pos := Vector3(
			(float(col) - float(COLS - 1) * 0.5) * SPACING_X,
			0.0,
			(float(row) - float(rows - 1) * 0.5) * SPACING_Z
		)
		var tier_data := GameState.get_tier(tier)
		var bomb := BombFactory.build(tier, false, tier_data)
		bomb.position = pos
		add_child(bomb)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "BOMB GALLERY  •  100 TIERS"
	title.add_theme_font_override("font", load(LABEL_FONT) as Font)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#FFC83D"))
	title.add_theme_color_override("font_outline_color", Color("#0B1020"))
	title.add_theme_constant_override("outline_size", 10)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 20.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(title)

	var legend := Label.new()
	legend.text = "25 HYPER    •    50 APEX    •    75 TRANSCENDENT    •    100 SINGULARITY"
	legend.add_theme_font_override("font", load(LABEL_FONT) as Font)
	legend.add_theme_font_size_override("font_size", 20)
	legend.add_theme_color_override("font_color", Color("#EAF0FF"))
	legend.add_theme_color_override("font_outline_color", Color("#0B1020"))
	legend.add_theme_constant_override("outline_size", 8)
	legend.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	legend.offset_top = -44.0
	legend.offset_bottom = -12.0
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(legend)
