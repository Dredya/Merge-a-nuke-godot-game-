class_name BombFactory
extends RefCounted

## Builds every bomb tier from cached Godot primitives. Visuals are procedural:
## no imported meshes, textures or sounds.

const FONT_PATH := "res://assets/fonts/LilitaOne-Regular.ttf"

static var _font: Font
static var _label_font: Font


static func build(tier: int, low_quality: bool = false) -> Bomb:
	var bomb := Bomb.new()
	bomb.name = "BombT%d" % tier
	bomb.tier = tier

	var bob := Node3D.new()
	bob.name = "Bob"
	# Slightly oversized for readability on a phone; still fits inside a pad.
	bob.scale = Vector3.ONE * 1.15
	bomb.add_child(bob)
	var visual := Node3D.new()
	visual.name = "Visual"
	bob.add_child(visual)

	var shadow := LowPoly.blob_shadow(0.55)
	shadow.position = Vector3(0.0, 0.035, 0.0)
	bomb.add_child(shadow)

	var label_height := 1.75
	match tier:
		1:
			label_height = _build_classic(visual, bomb)
		2:
			label_height = _build_steel(visual, bomb)
		3:
			label_height = _build_tech(visual, bomb)
		4:
			label_height = _build_gold_missile(visual, bomb)
		5:
			label_height = _build_plasma(visual, bomb)
		6:
			label_height = _build_neon_warhead(visual, bomb)
		_:
			label_height = _build_placeholder(visual, bomb, tier)

	_add_label(bob, tier, label_height)
	bomb.setup(tier, low_quality)
	return bomb


# --- Tier 1: Classic --------------------------------------------------------

static func _build_classic(visual: Node3D, bomb: Bomb) -> float:
	var body_dark := LowPoly.material(Color("#151A30"), 0.05, 0.55)
	var body_light := LowPoly.material(Color("#5A6694"), 0.05, 0.5)
	LowPoly.add_mesh(visual, LowPoly.sphere(0.5, 12, 7), body_dark, Vector3(0.0, 0.5, 0.0), Vector3.ZERO, Vector3.ONE, "Body")
	LowPoly.add_mesh(visual, LowPoly.sphere(0.505, 12, 4, true), body_light, Vector3(0.0, 0.5, 0.0), Vector3.ZERO, Vector3.ONE, "BodyTop")

	var metal := LowPoly.material(Color("#8A93A8"), 0.65, 0.35)
	LowPoly.add_mesh(visual, LowPoly.cylinder(0.15, 0.17, 0.10, 10), metal, Vector3(0.0, 1.02, 0.0), Vector3.ZERO, Vector3.ONE, "Cap")
	LowPoly.add_mesh(visual, LowPoly.torus(0.165, 0.018, 12, 4), LowPoly.material(Color("#3A4058"), 0.2, 0.6), Vector3(0.0, 0.99, 0.0), Vector3.ZERO, Vector3.ONE, "CapRing")

	var fuse_mat := LowPoly.material(Color("#3A4058"), 0.2, 0.7)
	LowPoly.add_mesh(visual, LowPoly.cylinder(0.028, 0.028, 0.18, 6), fuse_mat, Vector3(0.03, 1.10, 0.0), Vector3(0.0, 0.0, -25.0), Vector3.ONE, "Fuse1")
	LowPoly.add_mesh(visual, LowPoly.cylinder(0.028, 0.028, 0.18, 6), fuse_mat, Vector3(0.12, 1.21, 0.0), Vector3(0.0, 0.0, -55.0), Vector3.ONE, "Fuse2")
	LowPoly.add_mesh(visual, LowPoly.cylinder(0.026, 0.026, 0.15, 6), fuse_mat, Vector3(0.23, 1.29, 0.0), Vector3(0.0, 0.0, -82.0), Vector3.ONE, "Fuse3")

	var spark_mat := LowPoly.material(Color("#FFC83D"), 0.0, 0.3, Color("#FFC83D"), 3.2, true)
	var spark := LowPoly.add_mesh(visual, LowPoly.sphere(0.06, 6, 4), spark_mat, Vector3(0.31, 1.36, 0.0), Vector3.ZERO, Vector3.ONE, "Spark")
	bomb.register_glow(spark)
	_add_spark_particles(visual, Vector3(0.31, 1.38, 0.0), Color("#FFC83D"), 6, 0.55, 0.4, 0.035)
	return 1.82


# --- Tier 2: Steel ----------------------------------------------------------

static func _build_steel(visual: Node3D, bomb: Bomb) -> float:
	var silver := LowPoly.material(Color("#F2F6FF"), 0.85, 0.18)
	var blue_steel := LowPoly.material(Color("#6C7BA8"), 0.8, 0.28)
	var dark := LowPoly.material(Color("#252B3D"), 0.5, 0.45)
	LowPoly.add_mesh(visual, LowPoly.sphere(0.52, 12, 7), silver, Vector3(0.0, 0.52, 0.0), Vector3.ZERO, Vector3.ONE, "Body")
	LowPoly.add_mesh(visual, LowPoly.torus(0.47, 0.065, 14, 5), blue_steel, Vector3(0.0, 0.46, 0.0), Vector3.ZERO, Vector3.ONE, "Band")
	LowPoly.add_mesh(visual, LowPoly.box(Vector3(0.08, 0.30, 0.24)), blue_steel, Vector3(-0.50, 0.44, 0.0), Vector3(0.0, 0.0, -12.0), Vector3.ONE, "FinL")
	LowPoly.add_mesh(visual, LowPoly.box(Vector3(0.08, 0.30, 0.24)), blue_steel, Vector3(0.50, 0.44, 0.0), Vector3(0.0, 0.0, 12.0), Vector3.ONE, "FinR")
	LowPoly.add_mesh(visual, LowPoly.cylinder(0.17, 0.19, 0.12, 10), dark, Vector3(0.0, 1.04, 0.0), Vector3.ZERO, Vector3.ONE, "Cap")
	LowPoly.add_mesh(visual, LowPoly.cylinder(0.20, 0.20, 0.035, 10), blue_steel, Vector3(0.0, 0.98, 0.0), Vector3.ZERO, Vector3.ONE, "CapRing")
	# Soft glossy highlight on the upper-left, cheap fake specular.
	var gloss := LowPoly.material(Color("#FFFFFF"), 0.0, 0.1, Color("#FFFFFF"), 0.35, true, 0.75)
	LowPoly.add_mesh(visual, LowPoly.sphere(0.10, 8, 4), gloss, Vector3(-0.22, 0.82, 0.18), Vector3.ZERO, Vector3(1.0, 0.7, 1.0), "Gloss")
	return 1.70


# --- Tier 3: Tech -----------------------------------------------------------

static func _build_tech(visual: Node3D, bomb: Bomb) -> float:
	var teal := LowPoly.material(Color("#3CD8C8"), 0.25, 0.35)
	var deep := LowPoly.material(Color("#0E3A4A"), 0.2, 0.5)
	var lime := LowPoly.material(Color("#B6F23C"), 0.0, 0.3, Color("#B6F23C"), 2.8, true)
	LowPoly.add_mesh(visual, LowPoly.sphere(0.5, 12, 4, true), teal, Vector3(0.0, 0.5, 0.0), Vector3.ZERO, Vector3.ONE, "BodyTop")
	LowPoly.add_mesh(visual, LowPoly.sphere(0.5, 12, 4, true), deep, Vector3(0.0, 0.5, 0.0), Vector3(180.0, 0.0, 0.0), Vector3.ONE, "BodyBottom")
	var ring := LowPoly.add_mesh(visual, LowPoly.torus(0.51, 0.042, 16, 5), lime, Vector3(0.0, 0.5, 0.0), Vector3.ZERO, Vector3.ONE, "EnergyRing")
	bomb.register_glow(ring)
	LowPoly.add_mesh(visual, LowPoly.cylinder(0.018, 0.026, 0.44, 6), deep, Vector3(0.13, 1.02, -0.06), Vector3(0.0, 0.0, -7.0), Vector3.ONE, "Antenna")
	var tip := LowPoly.add_mesh(visual, LowPoly.sphere(0.065, 6, 4), lime, Vector3(0.16, 1.25, -0.08), Vector3.ZERO, Vector3.ONE, "AntennaTip")
	bomb.register_glow(tip)
	# Little side tech pods.
	var pod_mat := LowPoly.material(Color("#1E6E76"), 0.3, 0.4)
	LowPoly.add_mesh(visual, LowPoly.box(Vector3(0.16, 0.12, 0.22)), pod_mat, Vector3(-0.44, 0.42, 0.0), Vector3(0.0, 0.0, -20.0), Vector3.ONE, "PodL")
	LowPoly.add_mesh(visual, LowPoly.box(Vector3(0.16, 0.12, 0.22)), pod_mat, Vector3(0.44, 0.42, 0.0), Vector3(0.0, 0.0, 20.0), Vector3.ONE, "PodR")
	return 1.70


# --- Tier 4: Gold missile ---------------------------------------------------

static func _build_gold_missile(visual: Node3D, bomb: Bomb) -> float:
	var gold := LowPoly.material(Color("#E3AA2D"), 0.7, 0.25)
	var bright_gold := LowPoly.material(Color("#FFE58A"), 0.55, 0.2)
	var dark_gold := LowPoly.material(Color("#A86A10"), 0.65, 0.35)
	var orange := LowPoly.material(Color("#FF9A3D"), 0.2, 0.35, Color("#FF9A3D"), 1.1)
	LowPoly.add_mesh(visual, LowPoly.capsule(0.27, 0.94, 12, 5), gold, Vector3(0.0, 0.55, 0.0), Vector3.ZERO, Vector3.ONE, "Body")
	LowPoly.add_mesh(visual, LowPoly.cylinder(0.0, 0.28, 0.36, 12), bright_gold, Vector3(0.0, 1.18, 0.0), Vector3.ZERO, Vector3.ONE, "Nose")
	LowPoly.add_mesh(visual, LowPoly.torus(0.275, 0.043, 14, 5), orange, Vector3(0.0, 0.60, 0.0), Vector3.ZERO, Vector3.ONE, "Stripe")
	LowPoly.add_mesh(visual, LowPoly.torus(0.275, 0.030, 14, 5), orange, Vector3(0.0, 0.43, 0.0), Vector3.ZERO, Vector3.ONE, "Stripe2")
	LowPoly.add_mesh(visual, LowPoly.box(Vector3(0.06, 0.28, 0.24)), dark_gold, Vector3(-0.31, 0.18, 0.0), Vector3(0.0, 0.0, -12.0), Vector3.ONE, "FinL")
	LowPoly.add_mesh(visual, LowPoly.box(Vector3(0.06, 0.28, 0.24)), dark_gold, Vector3(0.31, 0.18, 0.0), Vector3(0.0, 0.0, 12.0), Vector3.ONE, "FinR")
	# White glossy nose highlight.
	var gloss := LowPoly.material(Color("#FFFFFF"), 0.0, 0.05, Color("#FFFFFF"), 0.6, true, 0.9)
	LowPoly.add_mesh(visual, LowPoly.sphere(0.085, 8, 4), gloss, Vector3(-0.10, 1.20, 0.11), Vector3.ZERO, Vector3(0.75, 1.0, 0.75), "Gloss")
	var tip := LowPoly.add_mesh(visual, LowPoly.sphere(0.045, 6, 4), bright_gold, Vector3(0.0, 1.38, 0.0), Vector3.ZERO, Vector3.ONE, "Tip")
	bomb.register_glow(tip)
	return 1.82


# --- Tier 5: Plasma core ----------------------------------------------------

static func _build_plasma(visual: Node3D, bomb: Bomb) -> float:
	var shell := LowPoly.material(Color("#14070F"), 0.25, 0.35)
	var orange := LowPoly.material(Color("#FF9A3D"), 0.0, 0.3, Color("#FF9A3D"), 2.2, true)
	var gold := LowPoly.material(Color("#FFC83D"), 0.0, 0.3, Color("#FFC83D"), 2.2, true)
	var core_mat := LowPoly.material(Color("#FFF3B0"), 0.0, 0.25, Color("#FF6A3D"), 3.4, true)
	LowPoly.add_mesh(visual, LowPoly.sphere(0.42, 12, 7), shell, Vector3(0.0, 0.50, 0.0), Vector3.ZERO, Vector3.ONE, "Shell")
	var core := LowPoly.add_mesh(visual, LowPoly.sphere(0.20, 10, 6), core_mat, Vector3(0.0, 0.50, 0.0), Vector3.ZERO, Vector3.ONE, "Core")
	bomb.register_glow(core)
	var ring_a := Node3D.new()
	ring_a.name = "RingA"
	ring_a.position = Vector3(0.0, 0.50, 0.0)
	visual.add_child(ring_a)
	LowPoly.add_mesh(ring_a, LowPoly.torus(0.53, 0.030, 16, 5), orange, Vector3.ZERO, Vector3(90.0, 0.0, 0.0), Vector3.ONE, "RingMesh")
	bomb.register_spinner(ring_a, Vector3(0.0, 1.0, 0.0), 1.3)
	var ring_b := Node3D.new()
	ring_b.name = "RingB"
	ring_b.position = Vector3(0.0, 0.50, 0.0)
	visual.add_child(ring_b)
	LowPoly.add_mesh(ring_b, LowPoly.torus(0.59, 0.024, 16, 5), gold, Vector3.ZERO, Vector3(90.0, 0.0, 90.0), Vector3.ONE, "RingMesh")
	bomb.register_spinner(ring_b, Vector3(0.0, 0.2, 1.0), -0.95)
	return 1.52


# --- Tier 6: Neon warhead ---------------------------------------------------

static func _build_neon_warhead(visual: Node3D, bomb: Bomb) -> float:
	var pink := LowPoly.material(Color("#FF7A9A"), 0.2, 0.3)
	var magenta := LowPoly.material(Color("#C03A9A"), 0.25, 0.32)
	var purple := LowPoly.material(Color("#5A1FA0"), 0.3, 0.4)
	var cyan := LowPoly.material(Color("#4FE0FF"), 0.0, 0.25, Color("#4FE0FF"), 2.6, true)
	var glow_disc_mat := LowPoly.material_unique(Color("#4FE0FF"), Color("#4FE0FF"), 1.4, true, 0.32)

	LowPoly.add_mesh(visual, LowPoly.capsule(0.29, 0.90, 12, 5), pink, Vector3(0.0, 0.52, 0.0), Vector3.ZERO, Vector3.ONE, "Body")
	LowPoly.add_mesh(visual, LowPoly.cylinder(0.0, 0.30, 0.36, 12), magenta, Vector3(0.0, 1.15, 0.0), Vector3.ZERO, Vector3.ONE, "Nose")
	var stripe_a := LowPoly.add_mesh(visual, LowPoly.torus(0.295, 0.028, 16, 5), cyan, Vector3(0.0, 0.43, 0.0), Vector3.ZERO, Vector3.ONE, "StripeA")
	bomb.register_glow(stripe_a)
	var stripe_b := LowPoly.add_mesh(visual, LowPoly.torus(0.282, 0.024, 16, 5), cyan, Vector3(0.0, 0.63, 0.0), Vector3.ZERO, Vector3.ONE, "StripeB")
	bomb.register_glow(stripe_b)
	var cockpit := LowPoly.add_mesh(visual, LowPoly.sphere(0.085, 8, 5), cyan, Vector3(0.20, 0.80, 0.20), Vector3.ZERO, Vector3(1.0, 0.8, 1.0), "Cockpit")
	bomb.register_glow(cockpit)
	for i in range(4):
		var angle := float(i) * 90.0 + 45.0
		var rad := deg_to_rad(angle)
		LowPoly.add_mesh(
			visual,
			LowPoly.box(Vector3(0.055, 0.30, 0.22)),
			purple,
			Vector3(cos(rad) * 0.36, 0.19, sin(rad) * 0.36),
			Vector3(0.0, -angle, 0.0),
			Vector3.ONE,
			"Fin%d" % i
		)
	LowPoly.add_mesh(visual, LowPoly.cylinder(0.56, 0.56, 0.025, 20), glow_disc_mat, Vector3(0.0, 0.03, 0.0), Vector3.ZERO, Vector3.ONE, "GlowDisc")

	var orbit := Node3D.new()
	orbit.name = "OrbitLights"
	orbit.position = Vector3(0.0, 0.58, 0.0)
	visual.add_child(orbit)
	LowPoly.add_mesh(orbit, LowPoly.sphere(0.055, 6, 4), cyan, Vector3(0.54, 0.0, 0.0), Vector3.ZERO, Vector3.ONE, "LightA")
	LowPoly.add_mesh(orbit, LowPoly.sphere(0.055, 6, 4), cyan, Vector3(-0.54, 0.0, 0.0), Vector3.ZERO, Vector3.ONE, "LightB")
	bomb.register_spinner(orbit, Vector3(0.0, 1.0, 0.0), 1.15)
	return 1.82


# --- Placeholders for tiers 7-15 (replaced in step 3) -----------------------

static func _build_placeholder(visual: Node3D, bomb: Bomb, tier: int) -> float:
	var colors := [
		Color("#D7E3FF"), Color("#4FC3F7"), Color("#C77DFF"), Color("#FFB300"),
		Color("#7A4BFF"), Color("#8A2BE2"), Color("#FFE082"), Color("#8F7CFF"), Color("#FFFFFF"),
	]
	var col: Color = colors[clampi(tier - 7, 0, colors.size() - 1)]
	var body_mat := LowPoly.material(col, 0.5, 0.3)
	var glow_mat := LowPoly.material(col, 0.0, 0.2, col, 2.5, true)
	var radius := 0.46 + float(tier - 7) * 0.025
	LowPoly.add_mesh(visual, LowPoly.sphere(radius, 12, 7), body_mat, Vector3(0.0, 0.52, 0.0), Vector3.ZERO, Vector3.ONE, "Body")
	var ring := LowPoly.add_mesh(visual, LowPoly.torus(radius + 0.09, 0.035, 16, 5), glow_mat, Vector3(0.0, 0.52, 0.0), Vector3(20.0, 0.0, 30.0), Vector3.ONE, "Ring")
	bomb.register_glow(ring)
	return 1.55 + radius


# --- Shared helpers ---------------------------------------------------------

static func _add_label(parent: Node3D, tier: int, height: float) -> void:
	var label := Label3D.new()
	label.name = "TierLabel"
	label.text = str(tier)
	label.font = _get_label_font()
	label.font_size = 58
	label.pixel_size = 0.0055
	label.outline_size = 18
	label.modulate = Color.WHITE
	label.outline_modulate = Color("#0B1020")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.double_sided = true
	label.position = Vector3(0.0, height, 0.0)
	parent.add_child(label)


static func _get_label_font() -> Font:
	if _label_font == null:
		_label_font = load(FONT_PATH) as Font
	return _label_font


static func _add_spark_particles(
	parent: Node3D,
	position: Vector3,
	color: Color,
	amount: int,
	speed: float,
	lifetime: float,
	size: float
) -> void:
	var particles := CPUParticles3D.new()
	particles.name = "SparkParticles"
	particles.position = position
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = false
	particles.explosiveness = 0.4
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.04
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 45.0
	particles.gravity = Vector3(0.0, -1.2, 0.0)
	particles.initial_velocity_min = speed * 0.7
	particles.initial_velocity_max = speed * 1.4
	particles.scale_amount_min = size
	particles.scale_amount_max = size * 1.5
	particles.color = color
	particles.mesh = LowPoly.sphere(1.0, 4, 2)
	particles.material_override = LowPoly.material(color, 0.0, 0.2, color, 2.6, true)
	particles.emitting = true
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(particles)
