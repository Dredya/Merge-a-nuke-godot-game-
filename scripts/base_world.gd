class_name BaseWorld
extends Node3D

## The player's 3D plot: an Area 51 style desert test range.
##
## Sky, warm sun, sand island with dunes, a tarmac apron, a concrete/steel
## merge deck with 4x3 diamond slot pads, and the surrounding installation
## (chain-link fence, guard towers, radar dome, hangar, runway, warning sign).
## The fixed isometric camera frames the deck.

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
## Top surface of the sand island; all ground-level props sit on this plane.
const GROUND_TOP_Y := -1.9

# Installation palette: concrete deck, steel sides, desert sand, olive drab.
const C_TOP := Color("#7B8088")
const C_LEFT := Color("#3E4450")
const C_RIGHT := Color("#5A606B")
const C_UNDER_RIM := Color("#2F343C")
const C_PAD := Color("#8A8F99")
const C_PAD_EDGE := Color("#555A62")
const C_GROUND := Color("#D6BF96")
const C_SAND_DARK := Color("#B89B6E")
const C_TARMAC := Color("#3A3F47")
const C_LANE := Color("#D8DEE8")
const C_STEEL := Color("#7A7F88")
const C_STEEL_DARK := Color("#4A4F5A")
const C_OLIVE := Color("#5A6B3A")
const C_FENCE := Color("#9AA0A8")
const C_BEACON := Color("#FF4D3D")
const C_SIGN := Color("#FFC83D")
const C_HIGHLIGHT := Color("#B6F23C")
# Desert sky: pale blue overhead fading into warm sand haze at the horizon.
const C_SKY_TOP := Color("#6FA8D8")
const C_SKY_HORIZON := Color("#E8D4A8")
const C_SUN := Color("#FFF1D6")

var low_quality: bool = false
var camera: Camera3D
var slots_root: Node3D
var highlight: MeshInstance3D
var _props: Node3D = null
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
	_build_props()
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
	add_child(LowPoly.create_environment(
		not low_quality,
		C_SKY_TOP,
		C_SKY_HORIZON,
		C_GROUND,
		C_SKY_HORIZON
	))
	add_child(LowPoly.create_sun(C_SUN, 1.25))


func _build_ground() -> void:
	var ground_mat := LowPoly.material(C_GROUND, 0.0, 0.95)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	# A finite blocky sand island: orthographic cameras never see a true horizon,
	# so the island edge reads as the sky/ground divide.
	ground.mesh = LowPoly.cylinder(20.0, 19.2, 1.8, 28, false)
	ground.material_override = ground_mat
	ground.position = Vector3(0.0, GROUND_TOP_Y - 0.9, 0.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	_build_dunes()


func _build_dunes() -> void:
	# Sparse darker-sand ridges near the island edge sell the desert. They are
	# kept short and low (top always below the deck plane) so they can never
	# cover a bomb in the orthographic view.
	var dune_mat := LowPoly.material(C_SAND_DARK, 0.0, 0.95)
	var defs: Array[Dictionary] = [
		{"pos": Vector3(-13.0, -2.15, -8.5), "scale": Vector3(6.0, 0.75, 4.0)},
		{"pos": Vector3(-7.5, -2.15, -14.0), "scale": Vector3(5.0, 0.70, 3.5)},
		{"pos": Vector3(9.5, -2.15, -12.0), "scale": Vector3(4.6, 0.65, 3.2)},
		{"pos": Vector3(-14.5, -2.15, 7.0), "scale": Vector3(5.0, 0.60, 3.6)},
		{"pos": Vector3(13.0, -2.15, 8.5), "scale": Vector3(5.4, 0.62, 3.8)},
	]
	for i in range(defs.size()):
		var def: Dictionary = defs[i]
		LowPoly.add_mesh(
			self,
			LowPoly.sphere(1.0, 6, 3),
			dune_mat,
			def["pos"] as Vector3,
			Vector3.ZERO,
			def["scale"] as Vector3,
			"Dune%d" % i
		)


func _build_baseplate() -> void:
	var plate := Node3D.new()
	plate.name = "Baseplate"
	add_child(plate)

	var slab_size := Vector3(
		float(cols) * SLOT_SPACING + 2.0,
		SLAB_THICKNESS,
		float(rows) * SLOT_SPACING + 2.0
	)

	# Main chunky slab (steel body). The top and visible sides get their own
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
	# Thin dark under-rim grounds the slab against the tarmac apron.
	LowPoly.add_mesh(
		plate,
		LowPoly.box(Vector3(slab_size.x + 0.12, 0.12, slab_size.z + 0.12)),
		LowPoly.material(C_UNDER_RIM, 0.0, 0.95),
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


func _build_props() -> void:
	# Free any previously built props (rebuild path).
	if _props != null:
		remove_child(_props)
		_props.free()
		_props = null
	var root := Node3D.new()
	root.name = "Props"
	add_child(root)
	_props = root

	var slab_x := float(cols) * SLOT_SPACING + 2.0
	var slab_z := float(rows) * SLOT_SPACING + 2.0
	# Tarmac apron the installation sits on.
	var apron := Vector3(slab_x + 4.0, 0.12, slab_z + 4.0)
	LowPoly.add_mesh(
		root,
		LowPoly.box(apron),
		LowPoly.material(C_TARMAC, 0.0, 0.95),
		Vector3(0.0, GROUND_TOP_Y + 0.06, 0.0),
		Vector3.ZERO,
		Vector3.ONE,
		"Apron"
	)
	var hx := apron.x * 0.5
	var hz := apron.z * 0.5
	_build_fence(root, hx, hz)
	# Guard towers on the two back corners so they never cover the board.
	_build_tower(root, Vector3(-hx - 1.5, GROUND_TOP_Y, -hz - 1.5), "TowerL")
	_build_tower(root, Vector3(hx + 1.5, GROUND_TOP_Y, -hz - 1.5), "TowerR")
	_build_hangar(root, Vector3(0.0, GROUND_TOP_Y, -hz - 5.2))
	_build_radar(root, Vector3(-hx - 3.2, GROUND_TOP_Y, -1.2))
	_build_runway(root, hz)
	_build_sign(root, Vector3(hx + 1.8, GROUND_TOP_Y, -1.6))


func _build_fence(root: Node3D, hx: float, hz: float) -> void:
	# Chain-link panels on the two far sides only, leaving the near edge open so
	# nothing ever occludes the merge board. Posts carry red beacon lights.
	var post_mat := LowPoly.material(C_STEEL_DARK, 0.3, 0.5)
	var beacon_mat := LowPoly.material(
		C_BEACON, 0.0, 0.3, C_BEACON,
		0.0 if low_quality else 2.0, true
	)
	var h := 1.5
	var y := GROUND_TOP_Y + h * 0.5
	var gap := 1.8
	# Far -Z run, split into two panels leaving a gate gap in the middle.
	_build_fence_panel(
		root,
		Vector3(-(hx + gap * 0.5) * 0.5, y, -hz - 0.35),
		Vector3(hx - gap * 0.5, h, 0.06),
		"FenceBackL"
	)
	_build_fence_panel(
		root,
		Vector3((hx + gap * 0.5) * 0.5, y, -hz - 0.35),
		Vector3(hx - gap * 0.5, h, 0.06),
		"FenceBackR"
	)
	# Far -X run (full length).
	_build_fence_panel(
		root,
		Vector3(-hx - 0.35, y, 0.0),
		Vector3(0.06, h, hz * 2.0 + 2.0),
		"FenceLeft"
	)
	# Corner and gate posts.
	var post_positions: Array[Vector3] = [
		Vector3(-hx - 0.35, GROUND_TOP_Y, -hz - 0.35),
		Vector3(-gap * 0.5, GROUND_TOP_Y, -hz - 0.35),
		Vector3(gap * 0.5, GROUND_TOP_Y, -hz - 0.35),
		Vector3(hx + 0.35, GROUND_TOP_Y, -hz - 0.35),
		Vector3(-hx - 0.35, GROUND_TOP_Y, hz + 1.0),
	]
	for i in range(post_positions.size()):
		var p := post_positions[i]
		LowPoly.add_mesh(
			root,
			LowPoly.box(Vector3(0.14, 1.9, 0.14)),
			post_mat,
			p + Vector3(0.0, 0.95, 0.0),
			Vector3.ZERO,
			Vector3.ONE,
			"FencePost%d" % i
		)
		LowPoly.add_mesh(
			root,
			LowPoly.box(Vector3(0.2, 0.2, 0.2)),
			beacon_mat,
			p + Vector3(0.0, 1.98, 0.0),
			Vector3.ZERO,
			Vector3.ONE,
			"FenceBeacon%d" % i
		)


func _build_fence_panel(root: Node3D, center: Vector3, size: Vector3, tag: String) -> void:
	var panel_mat := LowPoly.material(C_FENCE, 0.15, 0.6, Color.BLACK, 0.0, false, 0.40)
	var rail_mat := LowPoly.material(C_STEEL, 0.35, 0.45)
	var h := size.y
	LowPoly.add_mesh(
		root,
		LowPoly.box(size),
		panel_mat,
		center,
		Vector3.ZERO,
		Vector3.ONE,
		tag + "Mesh"
	)
	LowPoly.add_mesh(
		root,
		LowPoly.box(Vector3(size.x, 0.08, size.z)),
		rail_mat,
		center + Vector3(0.0, h * 0.5, 0.0),
		Vector3.ZERO,
		Vector3.ONE,
		tag + "TopRail"
	)
	LowPoly.add_mesh(
		root,
		LowPoly.box(Vector3(size.x, 0.08, size.z)),
		rail_mat,
		center - Vector3(0.0, h * 0.5, 0.0),
		Vector3.ZERO,
		Vector3.ONE,
		tag + "BotRail"
	)


func _build_fence_run(root: Node3D, center: Vector3, size: Vector3, tag: String) -> void:
	# Kept for backward compatibility; delegates to _build_fence_panel.
	_build_fence_panel(root, center, size, tag)


func _build_tower(root: Node3D, pos: Vector3, tag: String) -> void:
	var leg_mat := LowPoly.material(C_STEEL_DARK, 0.3, 0.5)
	var deck_mat := LowPoly.material(C_OLIVE, 0.1, 0.8)
	var roof_mat := LowPoly.material(C_STEEL_DARK, 0.2, 0.7)
	var lamp_mat := LowPoly.material(
		C_SIGN, 0.0, 0.3, C_SIGN,
		0.0 if low_quality else 1.6, true
	)
	var legs: Array[Vector2] = [
		Vector2(-0.42, -0.42), Vector2(0.42, -0.42),
		Vector2(-0.42, 0.42), Vector2(0.42, 0.42)
	]
	for i in range(legs.size()):
		var l := legs[i]
		LowPoly.add_mesh(
			root,
			LowPoly.box(Vector3(0.16, 2.6, 0.16)),
			leg_mat,
			pos + Vector3(l.x, 1.3, l.y),
			Vector3.ZERO,
			Vector3.ONE,
			"%sLeg%d" % [tag, i]
		)
	LowPoly.add_mesh(
		root,
		LowPoly.box(Vector3(1.5, 0.18, 1.5)),
		deck_mat,
		pos + Vector3(0.0, 2.68, 0.0),
		Vector3.ZERO,
		Vector3.ONE,
		tag + "Deck"
	)
	LowPoly.add_mesh(
		root,
		LowPoly.box(Vector3(1.7, 0.14, 1.7)),
		roof_mat,
		pos + Vector3(0.0, 3.5, 0.0),
		Vector3.ZERO,
		Vector3.ONE,
		tag + "Roof"
	)
	LowPoly.add_mesh(
		root,
		LowPoly.box(Vector3(0.1, 0.7, 0.1)),
		roof_mat,
		pos + Vector3(0.0, 3.15, 0.0),
		Vector3.ZERO,
		Vector3.ONE,
		tag + "Strut"
	)
	LowPoly.add_mesh(
		root,
		LowPoly.box(Vector3(0.34, 0.26, 0.34)),
		lamp_mat,
		pos + Vector3(0.0, 2.9, 0.62),
		Vector3.ZERO,
		Vector3.ONE,
		tag + "Lamp"
	)


func _build_hangar(root: Node3D, pos: Vector3) -> void:
	var wall_mat := LowPoly.material(C_STEEL_DARK, 0.25, 0.6)
	var roof_mat := LowPoly.material(C_OLIVE, 0.1, 0.75)
	var door_mat := LowPoly.material(Color("#2B2F38"), 0.2, 0.7)
	var stripe_mat := LowPoly.material(
		C_SIGN, 0.0, 0.55, C_SIGN,
		0.0 if low_quality else 0.8
	)
	LowPoly.add_mesh(
		root,
		LowPoly.box(Vector3(6.4, 2.6, 3.4)),
		wall_mat,
		pos + Vector3(0.0, 1.3, 0.0),
		Vector3.ZERO,
		Vector3.ONE,
		"HangarBody"
	)
	# Ridge runs along X: triangle cross-section in ZY, extruded along X.
	LowPoly.add_mesh(
		root,
		LowPoly.prism(Vector3(3.6, 1.1, 6.6)),
		roof_mat,
		pos + Vector3(0.0, 3.1, 0.0),
		Vector3(0.0, 90.0, 0.0),
		Vector3.ONE,
		"HangarRoof"
	)
	LowPoly.add_mesh(
		root,
		LowPoly.box(Vector3(3.0, 1.9, 0.1)),
		door_mat,
		pos + Vector3(0.0, 0.95, 1.75),
		Vector3.ZERO,
		Vector3.ONE,
		"HangarDoor"
	)
	LowPoly.add_mesh(
		root,
		LowPoly.box(Vector3(3.2, 0.16, 0.12)),
		stripe_mat,
		pos + Vector3(0.0, 2.02, 1.78),
		Vector3.ZERO,
		Vector3.ONE,
		"HangarStripe"
	)


func _build_radar(root: Node3D, pos: Vector3) -> void:
	var base_mat := LowPoly.material(C_STEEL_DARK, 0.25, 0.6)
	var dome_mat := LowPoly.material(Color("#C8CED8"), 0.1, 0.5)
	LowPoly.add_mesh(
		root,
		LowPoly.cylinder(0.9, 1.1, 0.7, 8),
		base_mat,
		pos + Vector3(0.0, 0.35, 0.0),
		Vector3.ZERO,
		Vector3.ONE,
		"RadarBase"
	)
	LowPoly.add_mesh(
		root,
		LowPoly.sphere(1.15, 8, 3, true),
		dome_mat,
		pos + Vector3(0.0, 0.7, 0.0),
		Vector3.ZERO,
		Vector3.ONE,
		"RadarDome"
	)
	LowPoly.add_mesh(
		root,
		LowPoly.box(Vector3(0.12, 0.9, 0.12)),
		base_mat,
		pos + Vector3(0.0, 1.9, 0.0),
		Vector3.ZERO,
		Vector3.ONE,
		"RadarMast"
	)


func _build_runway(root: Node3D, hz: float) -> void:
	var tarmac := LowPoly.material(C_TARMAC, 0.0, 0.95)
	var lane := LowPoly.material(C_LANE, 0.0, 0.7, Color.WHITE, 0.0, true, 0.9)
	var z := hz + 4.2
	# Taxiway linking the apron to the strip.
	LowPoly.add_mesh(
		root,
		LowPoly.box(Vector3(2.4, 0.08, 3.0)),
		tarmac,
		Vector3(0.0, GROUND_TOP_Y + 0.04, hz + 1.5),
		Vector3.ZERO,
		Vector3.ONE,
		"Taxiway"
	)
	LowPoly.add_mesh(
		root,
		LowPoly.box(Vector3(22.0, 0.08, 2.6)),
		tarmac,
		Vector3(0.0, GROUND_TOP_Y + 0.04, z),
		Vector3.ZERO,
		Vector3.ONE,
		"Runway"
	)
	for i in range(5):
		var x := -8.0 + float(i) * 4.0
		LowPoly.add_mesh(
			root,
			LowPoly.box(Vector3(1.6, 0.02, 0.18)),
			lane,
			Vector3(x, GROUND_TOP_Y + 0.1, z),
			Vector3.ZERO,
			Vector3.ONE,
			"RunwayDash%d" % i
		)


func _build_sign(root: Node3D, pos: Vector3) -> void:
	# Face the sign toward the camera (azimuth 45 deg).
	var sign := Node3D.new()
	sign.name = "WarningSign"
	sign.position = pos
	sign.rotation_degrees = Vector3(0.0, 45.0, 0.0)
	root.add_child(sign)
	var post_mat := LowPoly.material(C_STEEL_DARK, 0.3, 0.5)
	var board_mat := LowPoly.material(
		C_SIGN, 0.0, 0.55, C_SIGN,
		0.0 if low_quality else 0.5
	)
	var dark_mat := LowPoly.material(Color("#2B2F38"), 0.0, 0.8)
	LowPoly.add_mesh(
		sign,
		LowPoly.box(Vector3(0.1, 1.1, 0.1)),
		post_mat,
		Vector3(-0.45, 0.55, 0.0),
		Vector3.ZERO,
		Vector3.ONE,
		"SignPostL"
	)
	LowPoly.add_mesh(
		sign,
		LowPoly.box(Vector3(0.1, 1.1, 0.1)),
		post_mat,
		Vector3(0.45, 0.55, 0.0),
		Vector3.ZERO,
		Vector3.ONE,
		"SignPostR"
	)
	LowPoly.add_mesh(
		sign,
		LowPoly.box(Vector3(1.4, 0.9, 0.08)),
		board_mat,
		Vector3(0.0, 1.35, 0.0),
		Vector3.ZERO,
		Vector3.ONE,
		"SignBoard"
	)
	# Two dark bars suggest printed warning text.
	LowPoly.add_mesh(
		sign,
		LowPoly.box(Vector3(1.0, 0.14, 0.02)),
		dark_mat,
		Vector3(0.0, 1.55, 0.05),
		Vector3.ZERO,
		Vector3.ONE,
		"SignLine1"
	)
	LowPoly.add_mesh(
		sign,
		LowPoly.box(Vector3(0.7, 0.12, 0.02)),
		dark_mat,
		Vector3(0.0, 1.25, 0.05),
		Vector3.ZERO,
		Vector3.ONE,
		"SignLine2"
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
	# Thin high desert clouds: fewer and flatter than a temperate sky.
	var cloud_mat := LowPoly.material(Color(1.0, 1.0, 1.0, 0.88), 0.0, 1.0, Color.WHITE, 0.12, true, 0.88)
	var cloud_defs: Array[Dictionary] = [
		{"pos": Vector3(-11.0, 16.0, -7.0), "scale": 1.25, "speed": 0.22},
		{"pos": Vector3(4.0, 17.5, 1.0), "scale": 0.95, "speed": 0.15},
		{"pos": Vector3(10.0, 15.0, -10.0), "scale": 0.8, "speed": 0.11},
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


func fit_camera(viewport_size: Vector2i) -> void:
	if camera == null:
		return
	var aspect := float(viewport_size.x) / float(maxi(1, viewport_size.y))
	var plot_w := float((cols - 1) * SLOT_SPACING + 2.6)
	var plot_h := float((rows - 1) * SLOT_SPACING + 2.6)
	var required_v := maxf(plot_h, plot_w / maxf(aspect, 0.01)) * 1.25
	camera.size = clampf(required_v, 18.0, 40.0)


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
	if _props != null:
		remove_child(_props)
		_props.free()
		_props = null
	_build_baseplate()
	_build_slots()
	_build_props()


func show_slot_highlight(index: int) -> void:
	if index < 0:
		highlight.visible = false
		return
	highlight.position = slot_position(index) + Vector3(0.0, 0.045, 0.0)
	highlight.visible = true


func hide_slot_highlight() -> void:
	highlight.visible = false
