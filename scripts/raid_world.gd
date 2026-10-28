class_name RaidWorld
extends Node3D

## Tiny 3D raid diorama: player launch pad, dotted arc and a glass/steel enemy city.

signal raid_complete

const PLAYER_POS := Vector3(-4.6, 0.0, 2.9)
const ENEMY_POS := Vector3(4.6, 0.0, -2.9)
const ARC_START := Vector3(-4.3, 1.5, 2.7)
const ARC_CONTROL := Vector3(0.4, 8.6, 0.2)
const ARC_END := Vector3(4.3, 1.6, -2.7)

const C_PLAYER_TOP := Color("#4CAF50")
const C_PLAYER_SIDE := Color("#2E7D32")
const C_PAD := Color("#66C26A")
# Modern glass/steel enemy city palette.
const C_CITY_TOP := Color("#6B7280")
const C_CITY_SIDE := Color("#4A4F5A")
const C_ROAD := Color("#2B2F38")
const C_LANE := Color("#D8DEE8")
const C_PLAZA := Color("#8A92A0")
const C_STEEL_A := Color("#8A92A0")
const C_STEEL_B := Color("#9AA2B0")
const C_STEEL_C := Color("#7A8290")
const C_STEEL_D := Color("#5A5F6B")
const C_GLASS_A := Color("#6FA8D8")
const C_GLASS_B := Color("#4E7FB0")
const C_WINDOW := Color("#7FD6FF")
const C_ENEMY_RED := Color("#E74C3C")
const C_ENEMY_CROWN := Color("#FF6A3D")

var low_quality: bool = false
var camera: Camera3D
var missile: Bomb
var trail: CPUParticles3D

var _launching: bool = false
var _progress: float = 0.0
var _shake_time: float = 0.0
var _rng := RandomNumberGenerator.new()


func setup(quality_low: bool = false) -> void:
	low_quality = quality_low
	_rng.randomize()
	add_child(LowPoly.create_environment(not low_quality))
	add_child(LowPoly.create_sun())
	_build_ground()
	_build_player_base()
	_build_enemy_base()
	_build_dotted_arc()
	_build_missile()
	_build_clouds()
	_build_camera()


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.mesh = LowPoly.cylinder(11.0, 10.4, 1.8, 28, false)
	ground.material_override = LowPoly.material(Color("#9BE08A"), 0.0, 0.95)
	ground.position = Vector3(0.0, -2.4, 0.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _build_player_base() -> void:
	var root := Node3D.new()
	root.position = PLAYER_POS
	add_child(root)
	LowPoly.add_mesh(root, LowPoly.box(Vector3(5.4, 1.2, 4.2)), LowPoly.material(C_PLAYER_SIDE), Vector3(0.0, -0.6, 0.0), Vector3.ZERO, Vector3.ONE, "PlayerSlab")
	LowPoly.add_mesh(root, LowPoly.box(Vector3(5.45, 0.08, 4.25)), LowPoly.material(C_PLAYER_TOP), Vector3(0.0, 0.04, 0.0), Vector3.ZERO, Vector3.ONE, "PlayerTop")
	LowPoly.add_mesh(root, LowPoly.box(Vector3(2.7, 0.10, 2.7)), LowPoly.material(C_PAD), Vector3(0.2, 0.1, 0.0), Vector3(0.0, 45.0, 0.0), Vector3.ONE, "LaunchPad")
	# A small blocky launcher rail behind the missile.
	LowPoly.add_mesh(root, LowPoly.box(Vector3(0.35, 1.7, 0.35)), LowPoly.material(Color("#3A4673")), Vector3(-1.2, 0.9, -1.1), Vector3.ZERO, Vector3.ONE, "RailL")
	LowPoly.add_mesh(root, LowPoly.box(Vector3(0.35, 1.7, 0.35)), LowPoly.material(Color("#3A4673")), Vector3(1.6, 0.9, -1.1), Vector3.ZERO, Vector3.ONE, "RailR")


func _build_enemy_base() -> void:
	var root := Node3D.new()
	root.position = ENEMY_POS
	add_child(root)

	var slab_side := LowPoly.material(C_CITY_SIDE, 0.0, 0.9)
	var slab_top := LowPoly.material(C_CITY_TOP, 0.0, 0.85)
	var road_mat := LowPoly.material(C_ROAD, 0.0, 0.95)
	var lane_mat := LowPoly.material(C_LANE, 0.0, 0.7, Color.WHITE, 0.0, true, 0.9)
	var plaza_mat := LowPoly.material(C_PLAZA, 0.0, 0.8)
	var steel_a := LowPoly.material(C_STEEL_A, 0.35, 0.4)
	var steel_b := LowPoly.material(C_STEEL_B, 0.45, 0.35)
	var steel_c := LowPoly.material(C_STEEL_C, 0.3, 0.45)
	var steel_d := LowPoly.material(C_STEEL_D, 0.55, 0.3)
	var glass_a := LowPoly.material(C_GLASS_A, 0.6, 0.12)
	var glass_b := LowPoly.material(C_GLASS_B, 0.55, 0.16)
	# Low quality keeps the windows readable but drops the emissive glow.
	var window_energy := 1.8 if not low_quality else 0.0
	var window_mat := LowPoly.material(C_WINDOW, 0.0, 0.2, C_WINDOW, window_energy)
	var red_mat := LowPoly.material(C_ENEMY_RED, 0.0, 0.35, C_ENEMY_RED, 2.4, true)
	var crown_mat := LowPoly.material(C_ENEMY_CROWN, 0.0, 0.3, C_ENEMY_CROWN, 2.8, true)

	# Concrete foundation with a raised top plate.
	LowPoly.add_mesh(root, LowPoly.box(Vector3(7.0, 0.6, 7.0)), slab_side, Vector3(0.0, -0.3, 0.0), Vector3.ZERO, Vector3.ONE, "CitySlab")
	LowPoly.add_mesh(root, LowPoly.box(Vector3(7.05, 0.08, 7.05)), slab_top, Vector3(0.0, 0.04, 0.0), Vector3.ZERO, Vector3.ONE, "CityTop")

	# Central plaza and four road spokes reaching the edges.
	LowPoly.add_mesh(root, LowPoly.box(Vector3(1.9, 0.06, 1.9)), plaza_mat, Vector3(0.0, 0.11, 0.0), Vector3.ZERO, Vector3.ONE, "Plaza")
	_add_road(root, Vector3(0.0, 0.11, -1.95), Vector3(1.2, 0.06, 2.1), road_mat, "RoadN")
	_add_road(root, Vector3(0.0, 0.11, 1.95), Vector3(1.2, 0.06, 2.1), road_mat, "RoadS")
	_add_road(root, Vector3(1.95, 0.11, 0.0), Vector3(2.1, 0.06, 1.2), road_mat, "RoadE")
	_add_road(root, Vector3(-1.95, 0.11, 0.0), Vector3(2.1, 0.06, 1.2), road_mat, "RoadW")
	# Dashed lane markings along both road axes.
	for i in range(4):
		var z: float = [-1.5, -2.2, 1.5, 2.2][i]
		LowPoly.add_mesh(root, LowPoly.box(Vector3(0.08, 0.02, 0.5)), lane_mat, Vector3(0.0, 0.145, z), Vector3.ZERO, Vector3.ONE, "LaneZ%d" % i)
		var x: float = [-1.5, -2.2, 1.5, 2.2][i]
		LowPoly.add_mesh(root, LowPoly.box(Vector3(0.5, 0.02, 0.08)), lane_mat, Vector3(x, 0.145, 0.0), Vector3.ZERO, Vector3.ONE, "LaneX%d" % i)

	# Steel-and-glass blocks ringing the plaza (two per quadrant).
	var buildings: Array[Dictionary] = [
		{"pos": Vector2(-1.4, -1.4), "size": Vector3(1.0, 2.0, 1.0), "wall": steel_a, "glass": glass_a},
		{"pos": Vector2(1.4, -1.4), "size": Vector3(1.0, 2.6, 1.0), "wall": steel_b, "glass": glass_b},
		{"pos": Vector2(-1.4, 1.4), "size": Vector3(1.0, 1.5, 1.0), "wall": steel_c, "glass": glass_a},
		{"pos": Vector2(1.4, 1.4), "size": Vector3(1.0, 1.7, 1.0), "wall": steel_a, "glass": glass_b},
		{"pos": Vector2(-2.6, -2.6), "size": Vector3(1.2, 2.7, 1.2), "wall": steel_d, "glass": glass_b},
		{"pos": Vector2(2.6, -2.6), "size": Vector3(1.2, 3.4, 1.2), "wall": steel_b, "glass": glass_a},
		{"pos": Vector2(-2.6, 2.6), "size": Vector3(1.2, 2.0, 1.2), "wall": steel_c, "glass": glass_a},
		{"pos": Vector2(2.6, 2.6), "size": Vector3(1.2, 2.2, 1.2), "wall": steel_d, "glass": glass_b},
	]
	for i in range(buildings.size()):
		var b: Dictionary = buildings[i]
		var size: Vector3 = b["size"]
		var p2: Vector2 = b["pos"]
		var center := Vector3(p2.x, 0.08 + size.y * 0.5, p2.y)
		_add_city_building(root, center, size, b["wall"] as Material, b["glass"] as Material, window_mat, red_mat, "Bldg%d" % i)

	# Central landmark tower with a red enemy crown.
	var landmark_size := Vector3(1.5, 4.6, 1.5)
	var landmark_center := Vector3(0.0, 0.08 + landmark_size.y * 0.5, 0.0)
	_add_city_building(root, landmark_center, landmark_size, steel_d, glass_a, window_mat, red_mat, "Landmark", false)
	LowPoly.add_mesh(root, LowPoly.box(Vector3(1.2, 0.28, 1.2)), crown_mat, Vector3(0.0, 4.82, 0.0), Vector3.ZERO, Vector3.ONE, "LandmarkCrown")
	LowPoly.add_mesh(root, LowPoly.box(Vector3(0.08, 0.7, 0.08)), steel_c, Vector3(0.0, 5.31, 0.0), Vector3.ZERO, Vector3.ONE, "LandmarkAntenna")
	LowPoly.add_mesh(root, LowPoly.box(Vector3(0.16, 0.16, 0.16)), red_mat, Vector3(0.0, 5.72, 0.0), Vector3.ZERO, Vector3.ONE, "LandmarkTip")

	# Corner warning beacons keep the city reading as hostile territory.
	var corners: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	for i in range(corners.size()):
		var cx := 3.35 * corners[i].x
		var cz := 3.35 * corners[i].y
		LowPoly.add_mesh(root, LowPoly.box(Vector3(0.09, 1.1, 0.09)), steel_c, Vector3(cx, 0.08 + 0.55, cz), Vector3.ZERO, Vector3.ONE, "LightPole%d" % i)
		LowPoly.add_mesh(root, LowPoly.box(Vector3(0.22, 0.22, 0.22)), red_mat, Vector3(cx, 0.08 + 1.18, cz), Vector3.ZERO, Vector3.ONE, "LightOrb%d" % i)


func _add_road(root: Node3D, pos: Vector3, size: Vector3, mat: Material, mesh_tag: String) -> void:
	LowPoly.add_mesh(root, LowPoly.box(size), mat, pos, Vector3.ZERO, Vector3.ONE, mesh_tag)


## One steel-framed, glass-fronted city block.
func _add_city_building(
	root: Node3D,
	center: Vector3,
	size: Vector3,
	wall: Material,
	glass: Material,
	window_mat: Material,
	trim_mat: Material,
	tag: String,
	roof_trim: bool = true
) -> void:
	LowPoly.add_mesh(root, LowPoly.box(size), wall, center, Vector3.ZERO, Vector3.ONE, tag + "_Body")

	# Glass curtain panels on the two camera-facing facades (+X and +Z).
	var panel_h := size.y * 0.74
	var panel_y := center.y + size.y * 0.04
	LowPoly.add_mesh(root, LowPoly.box(Vector3(size.x * 0.66, panel_h, 0.05)), glass, Vector3(center.x - size.x * 0.12, panel_y, center.z + size.z * 0.5 + 0.025), Vector3.ZERO, Vector3.ONE, tag + "_GlassZ")
	LowPoly.add_mesh(root, LowPoly.box(Vector3(0.05, panel_h, size.z * 0.66)), glass, Vector3(center.x + size.x * 0.5 + 0.025, panel_y, center.z - size.z * 0.12), Vector3.ZERO, Vector3.ONE, tag + "_GlassX")

	# Emissive window bands, two for short blocks and three for tall ones.
	var floors := 2
	if size.y >= 2.4:
		floors = 3
	for f in range(floors):
		var t := (float(f) + 1.0) / float(floors + 1)
		var y := center.y - size.y * 0.5 + size.y * t
		LowPoly.add_mesh(root, LowPoly.box(Vector3(size.x * 0.82, 0.12, 0.05)), window_mat, Vector3(center.x, y, center.z + size.z * 0.5 + 0.05), Vector3.ZERO, Vector3.ONE, tag + "_WinZ%d" % f)
		LowPoly.add_mesh(root, LowPoly.box(Vector3(0.05, 0.12, size.z * 0.82)), window_mat, Vector3(center.x + size.x * 0.5 + 0.05, y, center.z), Vector3.ZERO, Vector3.ONE, tag + "_WinX%d" % f)

	if roof_trim:
		# Thin red enemy accent line under the roofline (not a full roof plate).
		var trim_y := center.y + size.y * 0.5 - 0.1
		LowPoly.add_mesh(root, LowPoly.box(Vector3(size.x * 0.92, 0.06, 0.04)), trim_mat, Vector3(center.x, trim_y, center.z + size.z * 0.5 + 0.03), Vector3.ZERO, Vector3.ONE, tag + "_TrimZ")
		LowPoly.add_mesh(root, LowPoly.box(Vector3(0.04, 0.06, size.z * 0.92)), trim_mat, Vector3(center.x + size.x * 0.5 + 0.03, trim_y, center.z), Vector3.ZERO, Vector3.ONE, tag + "_TrimX")


func _build_dotted_arc() -> void:
	var dot_mat := LowPoly.material(Color.WHITE, 0.0, 0.2, Color.WHITE, 1.8, true, 0.9)
	var mesh := LowPoly.sphere(0.07, 6, 3)
	for i in range(22):
		var t := float(i) / 21.0
		var pos := _arc_point(t)
		LowPoly.add_mesh(self, mesh, dot_mat, pos, Vector3.ZERO, Vector3.ONE, "PathDot%d" % i)


func _build_missile() -> void:
	missile = BombFactory.build(6, low_quality, GameState.get_tier(6))
	missile.name = "RaidMissile"
	missile.position = ARC_START
	missile.scale = Vector3.ONE * 2.0
	add_child(missile)
	trail = CPUParticles3D.new()
	trail.name = "FlameTrail"
	trail.position = Vector3(0.0, -0.35, 0.0)
	trail.amount = 22
	trail.lifetime = 0.45
	trail.one_shot = false
	trail.emitting = false
	trail.local_coords = false
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.12
	trail.direction = Vector3(0.0, -1.0, 0.0)
	trail.spread = 25.0
	trail.gravity = Vector3(0.0, -0.5, 0.0)
	trail.initial_velocity_min = 0.1
	trail.initial_velocity_max = 0.4
	trail.scale_amount_min = 0.10
	trail.scale_amount_max = 0.24
	trail.color = Color("#FF9A3D")
	trail.mesh = LowPoly.sphere(1.0, 4, 2)
	trail.material_override = LowPoly.material(Color("#FF9A3D"), 0.0, 0.2, Color("#FF6A3D"), 3.0, true)
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	missile.add_child(trail)


func _build_clouds() -> void:
	var cloud_mat := LowPoly.material(Color(1.0, 1.0, 1.0, 0.92), 0.0, 1.0, Color.WHITE, 0.1, true, 0.92)
	var defs: Array[Vector3] = [
		Vector3(-8.0, 9.0, -4.0),
		Vector3(6.0, 10.0, 3.0),
		Vector3(10.0, 8.5, -8.0),
	]
	for pos in defs:
		var cloud := Node3D.new()
		cloud.position = pos
		cloud.scale = Vector3.ONE * 0.9
		add_child(cloud)
		LowPoly.add_mesh(cloud, LowPoly.box(Vector3(2.0, 0.45, 0.8)), cloud_mat, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, "PuffA")
		LowPoly.add_mesh(cloud, LowPoly.box(Vector3(1.1, 0.4, 0.7)), cloud_mat, Vector3(0.9, 0.18, 0.1), Vector3(0.0, 8.0, 0.0), Vector3.ONE, "PuffB")


func _build_camera() -> void:
	camera = LowPoly.create_camera(11.5)
	camera.position = Vector3(13.0, 11.0, 13.0)
	camera.rotation_degrees = Vector3(-32.0, 45.0, 0.0)
	add_child(camera)


func _arc_point(t: float) -> Vector3:
	var u := 1.0 - t
	return u * u * ARC_START + 2.0 * u * t * ARC_CONTROL + t * t * ARC_END


func launch() -> void:
	if _launching:
		return
	_launching = true
	reset_raid()
	missile.visible = true
	if not low_quality:
		trail.emitting = true
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, 1.2).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	if not low_quality:
		trail.emitting = false
	missile.visible = false
	_explode(ARC_END)
	await get_tree().create_timer(0.55).timeout
	_launching = false
	raid_complete.emit()


func reset_raid() -> void:
	_progress = 0.0
	if missile != null:
		missile.position = ARC_START
		missile.visible = true
	if trail != null:
		trail.emitting = false


func _set_progress(value: float) -> void:
	_progress = value
	if missile == null:
		return
	missile.position = _arc_point(value)
	# Slight nose-up tilt through the arc.
	missile.rotation_degrees = Vector3(0.0, 0.0, lerpf(18.0, -18.0, value))


func _explode(pos: Vector3) -> void:
	_shake_time = 0.42
	var flash := MeshInstance3D.new()
	flash.mesh = LowPoly.sphere(0.55, 8, 4)
	flash.material_override = LowPoly.material_unique(Color("#FFF3B0"), Color("#FF9A3D"), 5.0, true, 0.95)
	flash.position = pos
	add_child(flash)
	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "scale", Vector3.ONE * 2.4, 0.22)
	flash_tween.parallel().tween_property(flash.material_override as StandardMaterial3D, "albedo_color:a", 0.0, 0.3)
	flash_tween.finished.connect(func(): flash.queue_free())

	var ring := MeshInstance3D.new()
	ring.mesh = LowPoly.torus(0.8, 0.09, 18, 5)
	ring.material_override = LowPoly.material_unique(Color("#FF9A3D"), Color("#FF6A3D"), 2.8, true, 0.9)
	ring.position = Vector3(pos.x, 0.25, pos.z)
	ring.scale = Vector3.ONE * 0.3
	add_child(ring)
	var ring_tween := create_tween()
	ring_tween.tween_property(ring, "scale", Vector3.ONE * 3.2, 0.5)
	ring_tween.parallel().tween_property(ring.material_override as StandardMaterial3D, "albedo_color:a", 0.0, 0.55)
	ring_tween.finished.connect(func(): ring.queue_free())

	if not low_quality:
		var particles := CPUParticles3D.new()
		particles.position = pos
		particles.amount = 64
		particles.lifetime = 1.0
		particles.one_shot = true
		particles.explosiveness = 1.0
		particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 0.35
		particles.direction = Vector3(0.0, 1.0, 0.0)
		particles.spread = 180.0
		particles.gravity = Vector3(0.0, -7.0, 0.0)
		particles.initial_velocity_min = 3.5
		particles.initial_velocity_max = 8.0
		particles.scale_amount_min = 0.10
		particles.scale_amount_max = 0.26
		particles.color = Color("#FF9A3D")
		particles.mesh = LowPoly.sphere(1.0, 4, 2)
		particles.material_override = LowPoly.material(Color("#FF9A3D"), 0.0, 0.2, Color("#FF6A3D"), 3.2, true)
		particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(particles)
		particles.emitting = true
		get_tree().create_timer(1.6).timeout.connect(particles.queue_free)


func _process(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time -= delta
		camera.h_offset = _rng.randf_range(-0.16, 0.16)
		camera.v_offset = _rng.randf_range(-0.16, 0.16)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
