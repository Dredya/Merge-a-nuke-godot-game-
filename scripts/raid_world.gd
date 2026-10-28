class_name RaidWorld
extends Node3D

## Tiny 3D raid diorama: player launch pad, dotted arc, 2x2 enemy base.

signal raid_complete

const PLAYER_POS := Vector3(-4.6, 0.0, 2.9)
const ENEMY_POS := Vector3(4.6, 0.0, -2.9)
const ARC_START := Vector3(-4.3, 1.5, 2.7)
const ARC_CONTROL := Vector3(0.4, 8.6, 0.2)
const ARC_END := Vector3(4.3, 1.6, -2.7)

const C_PLAYER_TOP := Color("#4CAF50")
const C_PLAYER_SIDE := Color("#2E7D32")
const C_PAD := Color("#66C26A")
const C_ENEMY_TOP := Color("#C0392B")
const C_ENEMY_SIDE := Color("#7B241C")
const C_ENEMY_PAD := Color("#E74C3C")

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
	LowPoly.add_mesh(root, LowPoly.box(Vector3(5.6, 1.6, 5.6)), LowPoly.material(C_ENEMY_SIDE), Vector3(0.0, -0.8, 0.0), Vector3.ZERO, Vector3.ONE, "EnemySlab")
	LowPoly.add_mesh(root, LowPoly.box(Vector3(5.65, 0.1, 5.65)), LowPoly.material(C_ENEMY_TOP), Vector3(0.0, 0.05, 0.0), Vector3.ZERO, Vector3.ONE, "EnemyTop")
	for row in range(2):
		for col in range(2):
			LowPoly.add_mesh(
				root,
				LowPoly.box(Vector3(2.05, 0.08, 2.05)),
				LowPoly.material(C_ENEMY_PAD),
				Vector3((float(col) - 0.5) * 2.35, 0.11, (float(row) - 0.5) * 2.35),
				Vector3(0.0, 45.0, 0.0),
				Vector3.ONE,
				"EnemyPad_%d_%d" % [row, col]
			)
	# Blocky defenses.
	var wall := LowPoly.material(Color("#2C3E50"))
	var glow := LowPoly.material(Color("#FF6A3D"), 0.0, 0.2, Color("#FF6A3D"), 2.0, true)
	LowPoly.add_mesh(root, LowPoly.box(Vector3(0.45, 1.2, 0.45)), wall, Vector3(-2.0, 0.7, -2.0), Vector3.ZERO, Vector3.ONE, "TowerA")
	LowPoly.add_mesh(root, LowPoly.box(Vector3(0.45, 1.2, 0.45)), wall, Vector3(2.0, 0.7, -2.0), Vector3.ZERO, Vector3.ONE, "TowerB")
	LowPoly.add_mesh(root, LowPoly.box(Vector3(0.45, 1.2, 0.45)), wall, Vector3(-2.0, 0.7, 2.0), Vector3.ZERO, Vector3.ONE, "TowerC")
	LowPoly.add_mesh(root, LowPoly.box(Vector3(0.3, 0.3, 0.3)), glow, Vector3(-2.0, 1.45, -2.0), Vector3.ZERO, Vector3.ONE, "BeaconA")
	LowPoly.add_mesh(root, LowPoly.box(Vector3(0.3, 0.3, 0.3)), glow, Vector3(2.0, 1.45, -2.0), Vector3.ZERO, Vector3.ONE, "BeaconB")


func _build_dotted_arc() -> void:
	var dot_mat := LowPoly.material(Color.WHITE, 0.0, 0.2, Color.WHITE, 1.8, true, 0.9)
	var mesh := LowPoly.sphere(0.07, 6, 3)
	for i in range(22):
		var t := float(i) / 21.0
		var pos := _arc_point(t)
		LowPoly.add_mesh(self, mesh, dot_mat, pos, Vector3.ZERO, Vector3.ONE, "PathDot%d" % i)


func _build_missile() -> void:
	missile = BombFactory.build(6, low_quality)
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
