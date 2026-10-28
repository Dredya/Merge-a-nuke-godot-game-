extends Node3D

## Debug gallery: shows all 15 bomb tiers side by side for visual checks.
## Run directly: godot --path . scenes/bomb_gallery.tscn

const LABEL_FONT := "res://assets/fonts/LilitaOne-Regular.ttf"
const COLS := 3
const ROWS := 5
const SPACING_X := 2.7
const SPACING_Z := 2.45


func _ready() -> void:
	add_child(LowPoly.create_environment(true))
	add_child(LowPoly.create_sun())
	_build_ground()
	_build_camera()
	_build_bombs()
	_build_title()


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.mesh = LowPoly.cylinder(14.0, 13.0, 1.2, 32)
	ground.material_override = LowPoly.material(Color("#9BE08A"), 0.0, 0.95)
	ground.position = Vector3(0.0, -1.2, 0.0)
	add_child(ground)
	var pad := MeshInstance3D.new()
	pad.mesh = LowPoly.box(Vector3(15.0, 0.16, 10.0))
	pad.material_override = LowPoly.material(Color("#4CAF50"), 0.0, 0.9)
	pad.position = Vector3(0.0, -0.56, 0.0)
	add_child(pad)


func _build_camera() -> void:
	var camera := LowPoly.create_camera(25.0)
	camera.position = Vector3(22.0, 24.5, 22.0)
	add_child(camera)


func _build_bombs() -> void:
	for tier in range(1, 16):
		var index := tier - 1
		var col := index % COLS
		var row := index / COLS
		var pos := Vector3(
			(float(col) - float(COLS - 1) * 0.5) * SPACING_X,
			0.0,
			(float(row) - float(ROWS - 1) * 0.5) * SPACING_Z
		)
		var bomb := BombFactory.build(tier, false)
		bomb.position = pos
		add_child(bomb)

		var tier_data := GameState.get_tier(tier)
		var tier_name := tier_data.name if tier_data != null else "Tier %d" % tier
		var name_label := Label3D.new()
		name_label.text = "%d  %s" % [tier, tier_name]
		name_label.font = load(LABEL_FONT) as Font
		name_label.font_size = 34
		name_label.pixel_size = 0.012
		name_label.outline_size = 12
		name_label.modulate = Color("#EAF0FF")
		name_label.outline_modulate = Color("#0B1020")
		name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_label.double_sided = true
		name_label.position = pos + Vector3(0.0, 2.45, 0.0)
		add_child(name_label)


func _build_title() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "BOMB GALLERY  •  15 TIERS"
	title.add_theme_font_override("font", load(LABEL_FONT) as Font)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#FFC83D"))
	title.add_theme_color_override("font_outline_color", Color("#0B1020"))
	title.add_theme_constant_override("outline_size", 10)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 24.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(title)
