class_name BaseWorld
extends Node3D

## The player's 3D plot: sky, sun, blocky baseplate, 4x3 diamond slot pads,
## drifting clouds and the fixed isometric camera.

# Layout is configured at setup()/rebuild() time.
var cols: int = 2
var rows: int = 3
var SLOT_COUNT: int:
	get:
		return cols * rows
const SLOT_SPACING := 2.55
const PAD_SIZE := 1.72
const PAD_TOP_Y := 0.16
const SLAB_THICKNESS := 1.8  # 18 design units at 0.1 world scale.

const C_TOP := Color("#4CAF50")
const C_LEFT := Color("#2E7D32")
const C_RIGHT := Color("#3E9B43")
const C_PAD := Color("#66C26A")
const C_PAD_EDGE := Color("#55B85E")
const C_GROUND := Color("#9BE08A")
const C_HIGHLIGHT := Color("#B6F23C")

var low_quality: bool = false
var camera: Camera3D
var slots_root: Node3D
var highlight: MeshInstance3D
var _clouds: Array[Dictionary] = []
var _time: float = 0.0


func setup(quality_low: bool = false, p_cols: int = 2, p_rows: int = 3) -> void:
	low_quality = quality_low
	cols = maxi(1, p_cols)
	rows = maxi(1, p_rows)
	_build_environment()
	_build_ground()
	_build_baseplate()
	_build_slots()
	_build_highlight()
	_build_clouds()
	_build_camera()


func slot_position(index: int) -> Vector3:
	var col := index % cols
	var row := index / cols
	return Vector3(
		(float(col) - float(cols - 1) * 0.5) * SLOT_SPACING,
		PAD_TOP_Y,
		(float(row) - float(rows - 1) * 0.5) * SLOT_SPACING
	)


func _build_environment() -> void:
	add_child(LowPoly.create_environment(not low_quality))
	add_child(LowPoly.create_sun())


func _build_ground() -> void:
	var ground_mat := LowPoly.material(C_GROUND, 0.0, 0.95)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	# A finite blocky grass island: orthographic cameras never see a true horizon,
	# so the island edge reads as the sky/ground divide.
	ground.mesh = LowPoly.cylinder(20.0, 19.2, 1.8, 28, false)
	ground.material_override = ground_mat
	ground.position = Vector3(0.0, -2.8, 0.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _build_baseplate() -> void:
	var plate := Node3D.new()
	plate.name = "Baseplate"
	add_child(plate)

	var slab_size := Vector3(
		float(cols) * SLOT_SPACING + 2.0,
		SLAB_THICKNESS,
		float(rows) * SLOT_SPACING + 2.0
	)

	# Main chunky slab (dark green body). The top and visible sides get their own
	# flush colored plates so the block reads as three distinct Roblox-style faces.
	LowPoly.add_mesh(
		plate,
		LowPoly.box(slab_size),
		LowPoly.material(C_LEFT, 0.0, 0.9),
		Vector3(0.0, -SLAB_THICKNESS * 0.5, 0.0),
		Vector3.ZERO,
		Vector3.ONE,
		"Slab"
	)
	LowPoly.add_mesh(
		plate,
		LowPoly.box(Vector3(slab_size.x + 0.02, 0.08, slab_size.z + 0.02)),
		LowPoly.material(C_TOP, 0.0, 0.9),
		Vector3(0.0, 0.035, 0.0),
		Vector3.ZERO,
		Vector3.ONE,
		"TopFace"
	)
	# Left and right faces are slightly inset plates so they stay crisp.
	LowPoly.add_mesh(
		plate,
		LowPoly.box(Vector3(0.06, SLAB_THICKNESS, slab_size.z)),
		LowPoly.material(C_LEFT, 0.0, 0.9),
		Vector3(-slab_size.x * 0.5 - 0.028, -SLAB_THICKNESS * 0.5, 0.0),
		Vector3.ZERO,
		Vector3.ONE,
		"LeftFace"
	)
	LowPoly.add_mesh(
		plate,
		LowPoly.box(Vector3(0.06, SLAB_THICKNESS, slab_size.z)),
		LowPoly.material(C_RIGHT, 0.0, 0.9),
		Vector3(slab_size.x * 0.5 + 0.028, -SLAB_THICKNESS * 0.5, 0.0),
		Vector3.ZERO,
		Vector3.ONE,
		"RightFace"
	)
	# Thin dark under-rim grounds the slab against the grass.
	LowPoly.add_mesh(
		plate,
		LowPoly.box(Vector3(slab_size.x + 0.12, 0.12, slab_size.z + 0.12)),
		LowPoly.material(Color("#226B29"), 0.0, 0.95),
		Vector3(0.0, -SLAB_THICKNESS + 0.02, 0.0),
		Vector3.ZERO,
		Vector3.ONE,
		"UnderRim"
	)


func _build_slots() -> void:
	slots_root = Node3D.new()
	slots_root.name = "Slots"
	add_child(slots_root)

	var edge_mat := LowPoly.material(C_PAD_EDGE, 0.0, 0.9)
	var pad_mat := LowPoly.material(C_PAD, 0.0, 0.8)
	for i in range(SLOT_COUNT):
		var pos := slot_position(i)
		var pad := Node3D.new()
		pad.name = "Slot%d" % i
		pad.position = pos
		slots_root.add_child(pad)
		# Wider diamond base gives each pad a chunky lip.
		LowPoly.add_mesh(
			pad,
			LowPoly.box(Vector3(PAD_SIZE + 0.12, 0.045, PAD_SIZE + 0.12)),
			edge_mat,
			Vector3(0.0, -0.045, 0.0),
			Vector3(0.0, 45.0, 0.0),
			Vector3.ONE,
			"PadEdge"
		)
		LowPoly.add_mesh(
			pad,
			LowPoly.box(Vector3(PAD_SIZE, 0.05, PAD_SIZE)),
			pad_mat,
			Vector3(0.0, 0.0, 0.0),
			Vector3(0.0, 45.0, 0.0),
			Vector3.ONE,
			"Pad"
		)


func _build_highlight() -> void:
	highlight = MeshInstance3D.new()
	highlight.name = "SlotHighlight"
	highlight.mesh = LowPoly.torus(0.98, 0.055, 16, 6)
	var mat := LowPoly.material_unique(C_HIGHLIGHT, C_HIGHLIGHT, 2.4, true, 0.9)
	highlight.material_override = mat
	highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	highlight.position = Vector3(0.0, PAD_TOP_Y + 0.04, 0.0)
	highlight.visible = false
	add_child(highlight)


func _build_clouds() -> void:
	var cloud_mat := LowPoly.material(Color(1.0, 1.0, 1.0, 0.92), 0.0, 1.0, Color.WHITE, 0.15, true, 0.92)
	var cloud_defs: Array[Dictionary] = [
		{"pos": Vector3(-10.0, 15.5, -6.0), "scale": 1.35, "speed": 0.20},
		{"pos": Vector3(3.0, 17.0, 2.0), "scale": 1.0, "speed": 0.14},
		{"pos": Vector3(9.0, 14.5, -9.0), "scale": 0.85, "speed": 0.10},
		{"pos": Vector3(-12.0, 16.5, 5.0), "scale": 1.2, "speed": 0.16},
	]
	for def in cloud_defs:
		var cloud := Node3D.new()
		cloud.name = "Cloud"
		cloud.position = def["pos"]
		cloud.scale = Vector3.ONE * float(def["scale"])
		add_child(cloud)
		LowPoly.add_mesh(cloud, LowPoly.box(Vector3(2.4, 0.55, 0.9)), cloud_mat, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, "PuffA")
		LowPoly.add_mesh(cloud, LowPoly.box(Vector3(1.30, 0.48, 0.8)), cloud_mat, Vector3(1.1, 0.28, 0.12), Vector3(0.0, 8.0, 0.0), Vector3.ONE, "PuffB")
		LowPoly.add_mesh(cloud, LowPoly.box(Vector3(1.1, 0.42, 0.7)), cloud_mat, Vector3(-1.0, 0.2, -0.1), Vector3(0.0, -6.0, 0.0), Vector3.ONE, "PuffC")
		_clouds.append({"node": cloud, "speed": float(def["speed"])})


func _build_camera() -> void:
	camera = LowPoly.create_camera(28.5)
	# Frame the plot slightly above the vertical center; UI overlays the bottom.
	camera.position = Vector3(22.0, 23.4, 22.0)
	add_child(camera)


func _process(delta: float) -> void:
	_time += delta
	for cloud in _clouds:
		var node := cloud["node"] as Node3D
		node.position.x += float(cloud["speed"]) * delta
		if node.position.x > 15.0:
			node.position.x = -15.0
	if highlight.visible:
		var pulse := 0.55 + 0.45 * sin(_time * 6.0)
		var mat := highlight.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color.a = pulse
			mat.emission_energy_multiplier = 1.4 + pulse * 1.6


func rebuild(p_cols: int, p_rows: int) -> void:
	cols = maxi(1, p_cols)
	rows = maxi(1, p_rows)
	var plate := get_node_or_null("Baseplate")
	if plate != null:
		remove_child(plate)
		plate.free()
	if slots_root != null:
		remove_child(slots_root)
		slots_root.free()
		slots_root = null
	_build_baseplate()
	_build_slots()


func show_slot_highlight(index: int) -> void:
	if index < 0:
		highlight.visible = false
		return
	highlight.position = slot_position(index) + Vector3(0.0, 0.045, 0.0)
	highlight.visible = true


func hide_slot_highlight() -> void:
	highlight.visible = false
