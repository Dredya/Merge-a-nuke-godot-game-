class_name BombFactory
extends RefCounted

## Builds every bomb tier from cached Godot primitives. Visuals are procedural:
## no imported meshes, textures or sounds.

const FONT_PATH := "res://assets/fonts/LilitaOne-Regular.ttf"

static var _font: Font
static var _label_font: Font


static func build(tier: int, low_quality: bool = false, tier_data: NukeTier = null) -> Bomb:
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

	var build_id := ""
	if tier_data != null:
		build_id = tier_data.build_id
	if build_id.is_empty():
		build_id = _default_build_id(tier)

	var label_height := 1.75
	match build_id:
		"classic":
			label_height = _build_classic(visual, bomb)
		"steel":
			label_height = _build_steel(visual, bomb)
		"tech":
			label_height = _build_tech(visual, bomb)
		"gold_missile":
			label_height = _build_gold_missile(visual, bomb)
		"plasma_core":
			label_height = _build_plasma(visual, bomb)
		"neon_warhead":
			label_height = _build_neon_warhead(visual, bomb)
		"ion":
			label_height = _build_ion(visual, bomb)
		"crystal":
			label_height = _build_crystal(visual, bomb)
		"antimatter":
			label_height = _build_antimatter(visual, bomb)
		"solar_flare":
			label_height = _build_solar_flare(visual, bomb)
		"void":
			label_height = _build_void(visual, bomb)
		"quantum":
			label_height = _build_quantum(visual, bomb)
		"star_core":
			label_height = _build_star_core(visual, bomb)
		"galaxy":
			label_height = _build_galaxy(visual, bomb)
		"omega":
			label_height = _build_omega(visual, bomb)
		"procedural":
			label_height = _build_procedural(visual, bomb, tier, tier_data)
		"singularity":
			label_height = _build_singularity(visual, bomb)
		_:
			label_height = _build_by_tier(visual, bomb, tier)

	var shadow_radius := float(bomb.get_meta("shadow_radius", 0.55))
	shadow.scale = Vector3.ONE * (shadow_radius / 0.55)
	_add_label(bob, tier, label_height)
	bomb.setup(tier, low_quality)
	return bomb


static func _default_build_id(tier: int) -> String:
	match tier:
		1:
			return "classic"
		2:
			return "steel"
		3:
			return "tech"
		4:
			return "gold_missile"
		5:
			return "plasma_core"
		6:
			return "neon_warhead"
		7:
			return "ion"
		8:
			return "crystal"
		9:
			return "antimatter"
		10:
			return "solar_flare"
		11:
			return "void"
		12:
			return "quantum"
		13:
			return "star_core"
		14:
			return "galaxy"
		15:
			return "omega"
		100:
			return "singularity"
		_:
			return "procedural"


static func _build_by_tier(visual: Node3D, bomb: Bomb, tier: int) -> float:
	var build_id := _default_build_id(tier)
	match build_id:
		"classic":
			return _build_classic(visual, bomb)
		"steel":
			return _build_steel(visual, bomb)
		"tech":
			return _build_tech(visual, bomb)
		"gold_missile":
			return _build_gold_missile(visual, bomb)
		"plasma_core":
			return _build_plasma(visual, bomb)
		"neon_warhead":
			return _build_neon_warhead(visual, bomb)
		"ion":
			return _build_ion(visual, bomb)
		"crystal":
			return _build_crystal(visual, bomb)
		"antimatter":
			return _build_antimatter(visual, bomb)
		"solar_flare":
			return _build_solar_flare(visual, bomb)
		"void":
			return _build_void(visual, bomb)
		"quantum":
			return _build_quantum(visual, bomb)
		"star_core":
			return _build_star_core(visual, bomb)
		"galaxy":
			return _build_galaxy(visual, bomb)
		"omega":
			return _build_omega(visual, bomb)
		"singularity":
			return _build_singularity(visual, bomb)
		_:
			return _build_procedural(visual, bomb, tier, null)


# --- Tier 1: Classic --------------------------------------------------------

static func _build_classic(visual: Node3D, bomb: Bomb) -> float:
	var body_dark := LowPoly.material(Color("#151A30"), 0.05, 0.55)
	var body_light := LowPoly.material(Color("#5A6694"), 0.05, 0.5)
	LowPoly.add_mesh(visual, LowPoly.sphere(0.5, 12, 7), body_dark, Vector3(0.0, 0.5, 0.0), Vector3.ZERO, Vector3.ONE, "Body")
	LowPoly.add_mesh(visual, LowPoly.sphere(0.505, 12, 4, true), body_light, Vector3(0.0, 0.5, 0.0), Vector3.ZERO, Vector3.ONE, "BodyTop")

	var metal := LowPoly.material(Color("#8A93A8"), 0.65, 0.35)
	LowPoly.add_mesh(visual, LowPoly.cylinder(0.15, 0.17, 0.10, 8), metal, Vector3(0.0, 1.02, 0.0), Vector3.ZERO, Vector3.ONE, "Cap")

	var fuse_mat := LowPoly.material(Color("#3A4058"), 0.2, 0.7)
	LowPoly.add_mesh(visual, LowPoly.cylinder(0.028, 0.028, 0.18, 4), fuse_mat, Vector3(0.03, 1.10, 0.0), Vector3(0.0, 0.0, -25.0), Vector3.ONE, "Fuse1")
	LowPoly.add_mesh(visual, LowPoly.cylinder(0.028, 0.028, 0.18, 4), fuse_mat, Vector3(0.12, 1.21, 0.0), Vector3(0.0, 0.0, -55.0), Vector3.ONE, "Fuse2")
	LowPoly.add_mesh(visual, LowPoly.cylinder(0.026, 0.026, 0.15, 4), fuse_mat, Vector3(0.23, 1.29, 0.0), Vector3(0.0, 0.0, -82.0), Vector3.ONE, "Fuse3")

	var spark_mat := LowPoly.material(Color("#FFC83D"), 0.0, 0.3, Color("#FFC83D"), 3.2, true)
	var spark := LowPoly.add_mesh(visual, LowPoly.sphere(0.06, 4, 2), spark_mat, Vector3(0.31, 1.36, 0.0), Vector3.ZERO, Vector3.ONE, "Spark")
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
	LowPoly.add_mesh(visual, LowPoly.cylinder(0.17, 0.19, 0.12, 8), dark, Vector3(0.0, 1.04, 0.0), Vector3.ZERO, Vector3.ONE, "Cap")
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
	var tip := LowPoly.add_mesh(visual, LowPoly.sphere(0.065, 4, 2), lime, Vector3(0.16, 1.25, -0.08), Vector3.ZERO, Vector3.ONE, "AntennaTip")
	bomb.register_glow(tip)
	return 1.70


# --- Tier 4: Gold missile ---------------------------------------------------

static func _build_gold_missile(visual: Node3D, bomb: Bomb) -> float:
	var gold := LowPoly.material(Color("#E3AA2D"), 0.7, 0.25)
	var bright_gold := LowPoly.material(Color("#FFE58A"), 0.55, 0.2)
	var dark_gold := LowPoly.material(Color("#A86A10"), 0.65, 0.35)
	var orange := LowPoly.material(Color("#FF9A3D"), 0.2, 0.35, Color("#FF9A3D"), 1.1)
	LowPoly.add_mesh(visual, LowPoly.capsule(0.27, 0.94, 12, 5), gold, Vector3(0.0, 0.55, 0.0), Vector3.ZERO, Vector3.ONE, "Body")
	LowPoly.add_mesh(visual, LowPoly.cylinder(0.0, 0.28, 0.36, 6), bright_gold, Vector3(0.0, 1.18, 0.0), Vector3.ZERO, Vector3.ONE, "Nose")
	LowPoly.add_mesh(visual, LowPoly.torus(0.275, 0.043, 14, 5), orange, Vector3(0.0, 0.60, 0.0), Vector3.ZERO, Vector3.ONE, "Stripe")
	LowPoly.add_mesh(visual, LowPoly.box(Vector3(0.06, 0.28, 0.24)), dark_gold, Vector3(-0.31, 0.18, 0.0), Vector3(0.0, 0.0, -12.0), Vector3.ONE, "FinL")
	LowPoly.add_mesh(visual, LowPoly.box(Vector3(0.06, 0.28, 0.24)), dark_gold, Vector3(0.31, 0.18, 0.0), Vector3(0.0, 0.0, 12.0), Vector3.ONE, "FinR")
	# White glossy nose highlight.
	var gloss := LowPoly.material(Color("#FFFFFF"), 0.0, 0.05, Color("#FFFFFF"), 0.6, true, 0.9)
	LowPoly.add_mesh(visual, LowPoly.sphere(0.085, 4, 2), gloss, Vector3(-0.10, 1.20, 0.11), Vector3.ZERO, Vector3(0.75, 1.0, 0.75), "Gloss")
	var tip := LowPoly.add_mesh(visual, LowPoly.box(Vector3(0.07, 0.07, 0.07)), bright_gold, Vector3(0.0, 1.38, 0.0), Vector3.ZERO, Vector3.ONE, "Tip")
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
	var glow_disc_mat := LowPoly.material(Color("#4FE0FF"), 0.0, 0.25, Color("#4FE0FF"), 1.4, true, 0.32)

	LowPoly.add_mesh(visual, LowPoly.capsule(0.29, 0.90, 12, 5), pink, Vector3(0.0, 0.52, 0.0), Vector3.ZERO, Vector3.ONE, "Body")
	LowPoly.add_mesh(visual, LowPoly.cylinder(0.0, 0.30, 0.36, 6), magenta, Vector3(0.0, 1.15, 0.0), Vector3.ZERO, Vector3.ONE, "Nose")
	var stripe_a := LowPoly.add_mesh(visual, LowPoly.torus(0.295, 0.028, 6, 3), cyan, Vector3(0.0, 0.43, 0.0), Vector3.ZERO, Vector3.ONE, "StripeA")
	bomb.register_glow(stripe_a)
	var stripe_b := LowPoly.add_mesh(visual, LowPoly.torus(0.282, 0.024, 6, 3), cyan, Vector3(0.0, 0.63, 0.0), Vector3.ZERO, Vector3.ONE, "StripeB")
	bomb.register_glow(stripe_b)
	var cockpit := LowPoly.add_mesh(visual, LowPoly.sphere(0.085, 4, 2), cyan, Vector3(0.20, 0.80, 0.20), Vector3.ZERO, Vector3(1.0, 0.8, 1.0), "Cockpit")
	bomb.register_glow(cockpit)
	for i in range(2):
		var angle := float(i) * 180.0
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
	LowPoly.add_mesh(visual, LowPoly.cylinder(0.56, 0.56, 0.025, 6), glow_disc_mat, Vector3(0.0, 0.03, 0.0), Vector3.ZERO, Vector3.ONE, "GlowDisc")

	var orbit := Node3D.new()
	orbit.name = "OrbitLights"
	orbit.position = Vector3(0.0, 0.58, 0.0)
	visual.add_child(orbit)
	LowPoly.add_mesh(orbit, LowPoly.box(Vector3(0.09, 0.09, 0.09)), cyan, Vector3(0.54, 0.0, 0.0), Vector3.ZERO, Vector3.ONE, "LightA")
	LowPoly.add_mesh(orbit, LowPoly.box(Vector3(0.09, 0.09, 0.09)), cyan, Vector3(-0.54, 0.0, 0.0), Vector3.ZERO, Vector3.ONE, "LightB")
	bomb.register_spinner(orbit, Vector3(0.0, 1.0, 0.0), 1.15)
	return 1.82


# --- Tier 7: Ion ------------------------------------------------------------

static func _build_ion(visual: Node3D, bomb: Bomb) -> float:
	var chrome := LowPoly.material(Color("#D7E3FF"), 1.0, 0.08)
	var ring_mat := LowPoly.material(Color("#5AE0FF"), 0.0, 0.2, Color("#5AE0FF"), 2.7, true)
	var core_mat := LowPoly.material(Color("#EAFBFF"), 0.0, 0.15, Color("#5AE0FF"), 3.2, true)
	LowPoly.add_mesh(visual, LowPoly.sphere(0.36, 12, 6), chrome, Vector3(0.0, 0.55, 0.0), Vector3.ZERO, Vector3.ONE, "ChromeCore")
	var core := LowPoly.add_mesh(visual, LowPoly.sphere(0.13, 4, 2), core_mat, Vector3(0.0, 0.55, 0.0), Vector3.ZERO, Vector3.ONE, "IonCore")
	bomb.register_glow(core)

	for i in range(3):
		var spinner := Node3D.new()
		spinner.name = "CageRing%d" % i
		spinner.position = Vector3(0.0, 0.55, 0.0)
		visual.add_child(spinner)
		var ring_rot := Vector3.ZERO
		var axis := Vector3.UP
		var speed := 0.6
		match i:
			0:
				ring_rot = Vector3.ZERO
				axis = Vector3(0.0, 1.0, 0.0)
				speed = 0.6
			1:
				ring_rot = Vector3(90.0, 0.0, 0.0)
				axis = Vector3(0.0, 1.0, 0.0)
				speed = -0.42
			2:
				ring_rot = Vector3(0.0, 0.0, 90.0)
				axis = Vector3(1.0, 0.0, 0.0)
				speed = 0.34
		var ring := LowPoly.add_mesh(spinner, LowPoly.torus(0.62, 0.023, 14, 4), ring_mat, Vector3.ZERO, ring_rot, Vector3.ONE, "CageRing")
		bomb.register_glow(ring)
		bomb.register_spinner(spinner, axis, speed)
	return 1.68


# --- Tier 8: Crystal --------------------------------------------------------

static func _build_crystal(visual: Node3D, bomb: Bomb) -> float:
	var crystal := LowPoly.material(Color("#4FC3F7"), 0.2, 0.12, Color("#4FE0FF"), 0.55, false, 0.78, true)
	var crystal_dark := LowPoly.material(Color("#1565C0"), 0.25, 0.15, Color("#1565C0"), 0.25, false, 0.8, true)
	var core_mat := LowPoly.material(Color("#EAFBFF"), 0.0, 0.1, Color("#B3E5FC"), 3.5, true)
	LowPoly.add_mesh(visual, LowPoly.cylinder(0.0, 0.22, 0.80, 6), crystal, Vector3(0.0, 0.68, 0.0), Vector3.ZERO, Vector3.ONE, "CrystalTip")
	LowPoly.add_mesh(visual, LowPoly.cylinder(0.22, 0.22, 0.42, 6), crystal_dark, Vector3(0.0, 0.18, 0.0), Vector3.ZERO, Vector3.ONE, "CrystalBase")
	var core := LowPoly.add_mesh(visual, LowPoly.sphere(0.15, 8, 4), core_mat, Vector3(0.0, 0.58, 0.0), Vector3.ZERO, Vector3.ONE, "CrystalCore")
	bomb.register_glow(core)
	# Side shards lean outward; the low-poly facets catch the light.
	LowPoly.add_mesh(visual, LowPoly.prism(Vector3(0.28, 0.62, 0.28)), crystal, Vector3(-0.30, 0.34, -0.02), Vector3(12.0, 18.0, -28.0), Vector3.ONE, "ShardL")
	LowPoly.add_mesh(visual, LowPoly.prism(Vector3(0.22, 0.46, 0.22)), crystal_dark, Vector3(0.31, 0.27, 0.08), Vector3(-10.0, -22.0, 24.0), Vector3.ONE, "ShardR")
	LowPoly.add_mesh(visual, LowPoly.prism(Vector3(0.18, 0.38, 0.18)), crystal, Vector3(0.02, 0.24, -0.31), Vector3(24.0, 8.0, 12.0), Vector3.ONE, "ShardB")

	var orbit := Node3D.new()
	orbit.name = "FloatingShards"
	orbit.position = Vector3(0.0, 0.62, 0.0)
	visual.add_child(orbit)
	for i in range(3):
		var angle := float(i) * TAU / 3.0
		var shard := LowPoly.add_mesh(
			orbit,
			LowPoly.prism(Vector3(0.12, 0.30, 0.12)),
			crystal,
			Vector3(cos(angle) * 0.64, 0.0, sin(angle) * 0.64),
			Vector3(15.0, -rad_to_deg(angle), 20.0),
			Vector3.ONE,
			"FloatShard%d" % i
		)
		bomb.register_glow(shard)
	bomb.register_spinner(orbit, Vector3(0.0, 1.0, 0.0), 0.5)
	return 1.88


# --- Tier 9: Antimatter -----------------------------------------------------

static func _build_antimatter(visual: Node3D, bomb: Bomb) -> float:
	var black := LowPoly.material(Color("#111111"), 0.15, 0.55)
	var white := LowPoly.material(Color("#F5F5F5"), 0.15, 0.4)
	var seam_mat := LowPoly.material(Color("#C77DFF"), 0.0, 0.2, Color("#C77DFF"), 3.0, true)
	LowPoly.add_mesh(visual, LowPoly.sphere(0.45, 12, 4, true), white, Vector3(0.0, 0.595, 0.0), Vector3.ZERO, Vector3.ONE, "WhiteHalf")
	LowPoly.add_mesh(visual, LowPoly.sphere(0.45, 12, 4, true), black, Vector3(0.0, 0.505, 0.0), Vector3(180.0, 0.0, 0.0), Vector3.ONE, "BlackHalf")
	var seam := LowPoly.add_mesh(visual, LowPoly.torus(0.455, 0.032, 14, 4), seam_mat, Vector3(0.0, 0.55, 0.0), Vector3.ZERO, Vector3.ONE, "EnergySeam")
	bomb.register_glow(seam)

	var swirl := Node3D.new()
	swirl.name = "Swirl"
	swirl.position = Vector3(0.0, 0.55, 0.0)
	visual.add_child(swirl)
	for i in range(6):
		var angle := float(i) * TAU / 6.0
		LowPoly.add_mesh(
			swirl,
			LowPoly.box(Vector3(0.055, 0.055, 0.055)),
			seam_mat,
			Vector3(cos(angle) * 0.67, sin(angle * 2.0) * 0.16, sin(angle) * 0.67),
			Vector3(0.0, -rad_to_deg(angle), 0.0),
			Vector3.ONE,
			"SwirlDot%d" % i
		)
	bomb.register_spinner(swirl, Vector3(0.0, 1.0, 0.0), 1.8)
	return 1.70


# --- Tier 10: Solar flare ---------------------------------------------------

static func _build_solar_flare(visual: Node3D, bomb: Bomb) -> float:
	var sun_mat := LowPoly.material(Color("#FFB300"), 0.1, 0.3, Color("#FF9A3D"), 1.4, false)
	var flame_mat := LowPoly.material(Color("#FF6A3D"), 0.0, 0.3, Color("#FF6A3D"), 2.2, true)
	var bright := LowPoly.material(Color("#FFF3B0"), 0.0, 0.2, Color("#FFF3B0"), 3.0, true)
	LowPoly.add_mesh(visual, LowPoly.sphere(0.45, 12, 6), sun_mat, Vector3(0.0, 0.55, 0.0), Vector3.ZERO, Vector3.ONE, "Sun")
	var core := LowPoly.add_mesh(visual, LowPoly.sphere(0.18, 4, 2), bright, Vector3(0.0, 0.55, 0.0), Vector3.ZERO, Vector3.ONE, "SolarCore")
	bomb.register_glow(core)
	var corona := Node3D.new()
	corona.name = "Corona"
	corona.position = Vector3(0.0, 0.55, 0.0)
	visual.add_child(corona)
	for i in range(6):
		var angle := float(i) * TAU / 6.0
		var height := 0.38 if i % 2 == 0 else 0.26
		LowPoly.add_mesh(
			corona,
			LowPoly.cylinder(0.0, 0.085, height, 4),
			flame_mat,
			Vector3(cos(angle) * 0.45, 0.05, sin(angle) * 0.45),
			Vector3(0.0, -rad_to_deg(angle), 18.0),
			Vector3.ONE,
			"Flame%d" % i
		)
	bomb.register_spinner(corona, Vector3(0.0, 1.0, 0.0), 0.35)
	_add_spark_particles(visual, Vector3(0.0, 0.75, 0.0), Color("#FF9A3D"), 9, 0.8, 0.7, 0.045)
	return 1.68


# --- Tier 11: Void ----------------------------------------------------------

static func _build_void(visual: Node3D, bomb: Bomb) -> float:
	var void_mat := LowPoly.material(Color("#050008"), 0.05, 0.8)
	var purple := LowPoly.material(Color("#C77DFF"), 0.0, 0.25, Color("#C77DFF"), 2.8, true)
	LowPoly.add_mesh(visual, LowPoly.sphere(0.44, 12, 6), void_mat, Vector3(0.0, 0.55, 0.0), Vector3.ZERO, Vector3.ONE, "VoidSphere")
	var ring_pivot := Node3D.new()
	ring_pivot.name = "HorizonPivot"
	ring_pivot.position = Vector3(0.0, 0.55, 0.0)
	visual.add_child(ring_pivot)
	var ring := LowPoly.add_mesh(ring_pivot, LowPoly.torus(0.57, 0.032, 16, 4), purple, Vector3.ZERO, Vector3(8.0, 0.0, 10.0), Vector3.ONE, "EventHorizon")
	bomb.register_glow(ring)
	bomb.register_spinner(ring_pivot, Vector3(0.2, 1.0, 0.15), 0.4)

	var vortex := Node3D.new()
	vortex.name = "Vortex"
	vortex.position = Vector3(0.0, 0.55, 0.0)
	visual.add_child(vortex)
	for i in range(8):
		var angle := float(i) * TAU / 8.0
		LowPoly.add_mesh(
			vortex,
			LowPoly.box(Vector3(0.06, 0.06, 0.06)),
			purple,
			Vector3(cos(angle) * 0.78, 0.0, sin(angle) * 0.78),
			Vector3.ZERO,
			Vector3.ONE,
			"VortexDot%d" % i
		)
	bomb.register_vortex(vortex, 0.82, 0.55, 0.30)
	return 1.68


# --- Tier 12: Quantum nuke --------------------------------------------------

static func _build_quantum(visual: Node3D, bomb: Bomb) -> float:
	var shell_mat := LowPoly.material(Color("#8A2BE2"), 0.0, 0.1, Color("#4FE0FF"), 0.5, true, 0.20, true)
	var ring_mat := LowPoly.material(Color("#4FE0FF"), 0.0, 0.2, Color("#4FE0FF"), 2.4, true)
	LowPoly.add_mesh(visual, LowPoly.sphere(0.58, 12, 6), shell_mat, Vector3(0.0, 0.55, 0.0), Vector3.ZERO, Vector3.ONE, "QuantumShell")
	var core_mat := LowPoly.material_unique(Color("#8A2BE2"), Color("#4FE0FF"), 3.0, true)
	var core_pivot := Node3D.new()
	core_pivot.name = "QuantumCore"
	core_pivot.position = Vector3(0.0, 0.55, 0.0)
	visual.add_child(core_pivot)
	LowPoly.add_mesh(core_pivot, LowPoly.cylinder(0.0, 0.24, 0.32, 4), core_mat, Vector3(0.0, 0.16, 0.0), Vector3.ZERO, Vector3.ONE, "PyramidUp")
	LowPoly.add_mesh(core_pivot, LowPoly.cylinder(0.0, 0.24, 0.32, 4), core_mat, Vector3(0.0, -0.16, 0.0), Vector3(180.0, 0.0, 0.0), Vector3.ONE, "PyramidDown")
	bomb.register_hue_material(core_mat)
	bomb.register_spinner(core_pivot, Vector3(0.25, 1.0, 0.4), 1.1)
	for i in range(2):
		var ring_pivot := Node3D.new()
		ring_pivot.name = "QuantumRing%d" % i
		ring_pivot.position = Vector3(0.0, 0.55, 0.0)
		visual.add_child(ring_pivot)
		var rot := Vector3(90.0, 0.0, 0.0) if i == 0 else Vector3(0.0, 0.0, 90.0)
		var ring := LowPoly.add_mesh(ring_pivot, LowPoly.torus(0.64, 0.02, 12, 4), ring_mat, Vector3.ZERO, rot, Vector3.ONE, "QuantumRing")
		bomb.register_glow(ring)
		bomb.register_spinner(ring_pivot, Vector3(0.0, 1.0, 0.3), 0.5 if i == 0 else -0.38)
	return 1.80


# --- Tier 13: Star core -----------------------------------------------------

static func _build_star_core(visual: Node3D, bomb: Bomb) -> float:
	var star_mat := LowPoly.material(Color("#FFFDE7"), 0.0, 0.1, Color("#FFF176"), 4.2, true)
	var beam_mat := LowPoly.material(Color("#FFE082"), 0.0, 0.2, Color("#FFE082"), 2.4, true, 0.75)
	LowPoly.add_mesh(visual, LowPoly.sphere(0.30, 10, 5), star_mat, Vector3(0.0, 0.55, 0.0), Vector3.ZERO, Vector3.ONE, "Star")
	var beams := Node3D.new()
	beams.name = "LightBeams"
	beams.position = Vector3(0.0, 0.55, 0.0)
	visual.add_child(beams)
	for i in range(4):
		var angle := float(i) * 45.0
		var beam := LowPoly.add_mesh(
			beams,
			LowPoly.box(Vector3(1.32, 0.045, 0.045)),
			beam_mat,
			Vector3.ZERO,
			Vector3(0.0, angle, 0.0),
			Vector3.ONE,
			"Beam%d" % i
		)
		bomb.register_glow(beam)
	bomb.register_spinner(beams, Vector3(0.0, 1.0, 0.0), 0.45)
	var core := LowPoly.add_mesh(visual, LowPoly.sphere(0.15, 4, 2), star_mat, Vector3(0.0, 0.55, 0.0), Vector3.ZERO, Vector3.ONE, "StarCore")
	bomb.register_glow(core)

	var orbit := Node3D.new()
	orbit.name = "Planets"
	orbit.position = Vector3(0.0, 0.55, 0.0)
	visual.add_child(orbit)
	var planet_colors := [Color("#4FE0FF"), Color("#B6F23C"), Color("#FF7A9A")]
	var radii: Array[float] = [0.66, 0.82, 0.96]
	for i in range(3):
		var pcol: Color = planet_colors[i]
		var planet_mat := LowPoly.material(pcol, 0.15, 0.35, pcol, 0.6)
		LowPoly.add_mesh(
			orbit,
			LowPoly.sphere(0.075, 4, 2),
			planet_mat,
			Vector3(radii[i], 0.05 * float(i - 1), 0.0),
			Vector3.ZERO,
			Vector3.ONE,
			"Planet%d" % i
		)
	orbit.rotation_degrees.y = 25.0
	bomb.register_spinner(orbit, Vector3(0.0, 1.0, 0.0), 0.55)
	return 1.60


# --- Tier 14: Galaxy --------------------------------------------------------

static func _build_galaxy(visual: Node3D, bomb: Bomb) -> float:
	var dark := LowPoly.material(Color("#0B0B1E"), 0.35, 0.6)
	LowPoly.add_mesh(visual, LowPoly.sphere(0.48, 10, 5), dark, Vector3(0.0, 0.55, 0.0), Vector3.ZERO, Vector3.ONE, "GalaxySphere")
	var swirl := Node3D.new()
	swirl.name = "GalaxySwirl"
	swirl.position = Vector3(0.0, 0.55, 0.0)
	swirl.rotation_degrees = Vector3(18.0, 0.0, -10.0)
	visual.add_child(swirl)
	var palette := [
		LowPoly.material(Color("#FFFFFF"), 0.0, 0.2, Color("#FFFFFF"), 2.4, true),
		LowPoly.material(Color("#8F7CFF"), 0.0, 0.2, Color("#8F7CFF"), 2.4, true),
		LowPoly.material(Color("#FF7AD9"), 0.0, 0.2, Color("#FF7AD9"), 2.2, true),
		LowPoly.material(Color("#6AD7FF"), 0.0, 0.2, Color("#6AD7FF"), 2.2, true),
	]
	for i in range(10):
		var t := float(i) / 9.0
		var radius := 0.06 + t * 0.40
		var angle := t * 2.15 * TAU
		var surface_y := sqrt(maxf(0.2304 - radius * radius, 0.0))
		LowPoly.add_mesh(
			swirl,
			LowPoly.box(Vector3(0.06, 0.035, 0.06)),
			palette[i % palette.size()],
			Vector3(cos(angle) * radius, surface_y + 0.01, sin(angle) * radius),
			Vector3(0.0, -rad_to_deg(angle), 0.0),
			Vector3.ONE,
			"StarVoxel%d" % i
		)
	bomb.register_spinner(swirl, Vector3(0.0, 1.0, 0.0), 0.32)
	var ring_mat := LowPoly.material(Color("#8F7CFF"), 0.0, 0.2, Color("#8F7CFF"), 2.0, true, 0.8)
	var ring := LowPoly.add_mesh(visual, LowPoly.torus(0.62, 0.018, 16, 4), ring_mat, Vector3(0.0, 0.55, 0.0), Vector3(20.0, 0.0, 15.0), Vector3.ONE, "GalaxyRing")
	bomb.register_glow(ring)
	_add_drift_particles(visual, Vector3(0.0, 0.55, 0.0), Color("#8F7CFF"), 8)
	return 1.72


# --- Tier 15: Omega nuke ----------------------------------------------------

static func _build_omega(visual: Node3D, bomb: Bomb) -> float:
	visual.scale = Vector3.ONE * 1.12
	var haze := LowPoly.material(Color("#FFFFFF"), 0.0, 0.1, Color("#FFC83D"), 1.6, true, 0.16, true)
	var gold := LowPoly.material(Color("#FFC83D"), 0.0, 0.2, Color("#FFC83D"), 2.6, true)
	var cyan := LowPoly.material(Color("#4FE0FF"), 0.0, 0.2, Color("#4FE0FF"), 2.4, true)
	var core_mat := LowPoly.material_unique(Color("#FFFFFF"), Color("#FFC83D"), 3.8, true)
	LowPoly.add_mesh(visual, LowPoly.sphere(0.62, 6, 3), haze, Vector3(0.0, 0.58, 0.0), Vector3.ZERO, Vector3.ONE, "OmegaHaze")
	var core := LowPoly.add_mesh(visual, LowPoly.sphere(0.40, 6, 3), core_mat, Vector3(0.0, 0.58, 0.0), Vector3.ZERO, Vector3.ONE, "OmegaCore")
	bomb.register_hue_material(core_mat)
	bomb.register_glow(core)

	var crown_defs: Array[Dictionary] = [
		{"radius": 0.72, "rot": Vector3.ZERO, "axis": Vector3(0.0, 1.0, 0.0), "speed": 0.55, "mat": gold},
		{"radius": 0.82, "rot": Vector3(90.0, 0.0, 20.0), "axis": Vector3(0.2, 1.0, 0.0), "speed": -0.38, "mat": cyan},
		{"radius": 0.90, "rot": Vector3(20.0, 0.0, 90.0), "axis": Vector3(1.0, 0.2, 0.0), "speed": 0.30, "mat": gold},
	]
	for i in range(crown_defs.size()):
		var def: Dictionary = crown_defs[i]
		var pivot := Node3D.new()
		pivot.name = "CrownRing%d" % i
		pivot.position = Vector3(0.0, 0.58, 0.0)
		visual.add_child(pivot)
		var ring := LowPoly.add_mesh(
			pivot,
			LowPoly.torus(float(def["radius"]), 0.024, 6, 3),
			def["mat"] as Material,
			Vector3.ZERO,
			def["rot"] as Vector3,
			Vector3.ONE,
			"CrownRing"
		)
		bomb.register_glow(ring)
		bomb.register_spinner(pivot, def["axis"] as Vector3, float(def["speed"]))

	var crown := Node3D.new()
	crown.name = "CrownBlocks"
	crown.position = Vector3(0.0, 1.22, 0.0)
	visual.add_child(crown)
	for i in range(6):
		var angle := float(i) * TAU / 6.0
		var block := LowPoly.add_mesh(
			crown,
			LowPoly.box(Vector3(0.10, 0.16, 0.10)),
			gold,
			Vector3(cos(angle) * 0.62, 0.0, sin(angle) * 0.62),
			Vector3(0.0, -rad_to_deg(angle), 0.0),
			Vector3.ONE,
			"CrownBlock%d" % i
		)
		bomb.register_glow(block)
	bomb.register_spinner(crown, Vector3(0.0, 1.0, 0.0), -0.65)
	_add_spark_particles(visual, Vector3(0.0, 0.75, 0.0), Color("#FFC83D"), 12, 1.1, 0.9, 0.04)
	_add_spark_particles(visual, Vector3(0.0, 0.55, 0.0), Color("#4FE0FF"), 8, 0.9, 0.85, 0.032)
	return 2.25


# --- Tiers 16-99: procedural escalation -------------------------------------

static func _build_procedural(visual: Node3D, bomb: Bomb, tier: int, tier_data: NukeTier) -> float:
	var t := clampf(float(tier - 16) / 83.0, 0.0, 1.0)
	var primary: Color
	var secondary: Color
	var accent: Color
	var glow: Color
	if tier_data != null:
		primary = tier_data.color
		secondary = tier_data.color_secondary
		accent = tier_data.color_accent
		glow = tier_data.glow_color
	else:
		var hue := 0.50 + t * 0.35
		primary = Color.from_hsv(hue, 0.78, 0.92)
		secondary = Color.from_hsv(fmod(hue + 0.06, 1.0), 0.75, 0.55)
		accent = Color.from_hsv(fmod(hue + 0.12, 1.0), 0.55, 1.0)
		glow = Color.from_hsv(hue, 0.65, 1.0)

	var body_mat := LowPoly.material(primary, 0.35, 0.3)
	var secondary_mat := LowPoly.material(secondary, 0.4, 0.4)
	var glow_mat := LowPoly.material(glow, 0.0, 0.2, glow, 2.4 + t * 2.2, true)
	var accent_mat := LowPoly.material(accent, 0.0, 0.2, accent, 2.0 + t * 1.6, true)

	var radius := 0.45 + t * 0.25
	var center_y := radius + 0.10
	LowPoly.add_mesh(visual, LowPoly.sphere(radius, 8, 4), body_mat, Vector3(0.0, center_y, 0.0), Vector3.ZERO, Vector3.ONE, "Body")

	var core_radius := 0.13 + t * 0.09
	var core := LowPoly.add_mesh(visual, LowPoly.sphere(core_radius, 6, 3), glow_mat, Vector3(0.0, center_y, 0.0), Vector3.ZERO, Vector3.ONE, "Core")
	bomb.register_glow(core)

	var ring_count := 2
	if t >= 0.34:
		ring_count = 3
	if t >= 0.67:
		ring_count = 4
	for i in range(ring_count):
		var pivot := Node3D.new()
		pivot.name = "RingPivot%d" % i
		pivot.position = Vector3(0.0, center_y, 0.0)
		visual.add_child(pivot)
		var ring_rot := Vector3.ZERO
		var axis := Vector3(0.0, 1.0, 0.0)
		var speed := 0.45 + t * 0.45
		match i:
			0:
				ring_rot = Vector3.ZERO
			1:
				ring_rot = Vector3(90.0, 0.0, 0.0)
				axis = Vector3(0.0, 1.0, 0.0)
				speed = -0.38 - t * 0.25
			2:
				ring_rot = Vector3(0.0, 0.0, 90.0)
				axis = Vector3(1.0, 0.0, 0.0)
				speed = 0.32 + t * 0.3
			3:
				ring_rot = Vector3(45.0, 0.0, 45.0)
				axis = Vector3(1.0, 0.3, 0.0)
				speed = -0.26 - t * 0.2
		var ring_mat := glow_mat if i % 2 == 0 else accent_mat
		var ring := LowPoly.add_mesh(
			pivot,
			LowPoly.torus(radius + 0.12 + float(i) * 0.05, 0.024 + t * 0.004, 6, 3),
			ring_mat,
			Vector3.ZERO,
			ring_rot,
			Vector3.ONE,
			"Ring%d" % i
		)
		bomb.register_glow(ring)
		bomb.register_spinner(pivot, axis, speed)

	for i in range(2):
		var sign := -1.0 if i == 0 else 1.0
		LowPoly.add_mesh(
			visual,
			LowPoly.box(Vector3(0.06, radius * 0.72, radius * 0.48)),
			secondary_mat,
			Vector3(sign * (radius + 0.10), center_y - radius * 0.3, 0.0),
			Vector3(0.0, 0.0, sign * -10.0),
			Vector3.ONE,
			"Fin%d" % i
		)

	if t >= 0.5:
		var orbit := Node3D.new()
		orbit.name = "OrbitShards"
		orbit.position = Vector3(0.0, center_y, 0.0)
		visual.add_child(orbit)
		for i in range(2):
			var angle := float(i) * PI
			LowPoly.add_mesh(
				orbit,
				LowPoly.box(Vector3(0.08, 0.22, 0.08)),
				accent_mat,
				Vector3(cos(angle) * (radius + 0.30), 0.0, sin(angle) * (radius + 0.30)),
				Vector3(10.0, -rad_to_deg(angle), 15.0),
				Vector3.ONE,
				"Shard%d" % i
			)
		bomb.register_spinner(orbit, Vector3(0.0, 1.0, 0.0), 0.7 + t * 0.5)

	bomb.set_meta("shadow_radius", radius + 0.12)
	return center_y + radius + 0.55


# --- Tier 100: Singularity ---------------------------------------------------

static func _build_singularity(visual: Node3D, bomb: Bomb) -> float:
	var height := _build_omega(visual, bomb)
	visual.scale = Vector3.ONE * 1.30
	var gold := LowPoly.material(Color("#FFC83D"), 0.0, 0.2, Color("#FFC83D"), 2.8, true)
	var cyan := LowPoly.material(Color("#4FE0FF"), 0.0, 0.2, Color("#4FE0FF"), 2.6, true)
	var orbit := Node3D.new()
	orbit.name = "SingularityShards"
	orbit.position = Vector3(0.0, 0.58, 0.0)
	visual.add_child(orbit)
	for i in range(4):
		var angle := float(i) * TAU / 4.0
		var shard_mat := gold if i % 2 == 0 else cyan
		var shard := LowPoly.add_mesh(
			orbit,
			LowPoly.prism(Vector3(0.15, 0.32, 0.15)),
			shard_mat,
			Vector3(cos(angle) * 0.84, 0.0, sin(angle) * 0.84),
			Vector3(12.0, -rad_to_deg(angle), 18.0),
			Vector3.ONE,
			"Shard%d" % i
		)
		bomb.register_glow(shard)
	bomb.register_spinner(orbit, Vector3(0.0, 1.0, 0.0), -0.9)
	bomb.set_meta("shadow_radius", 0.90)
	return height + 0.20



# --- Shared helpers ---------------------------------------------------------

static func _add_label(parent: Node3D, tier: int, height: float) -> void:
	var label := Label3D.new()
	label.name = "TierLabel"
	# Display the doubled value (2^(tier-1)), not the internal tier index.
	label.text = _format_value(tier)
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


static func _format_value(tier: int) -> String:
	# Compact display of 2^(tier-1), mirroring Economy.format_number.
	var value := pow(2.0, float(tier - 1))
	if value >= 1.0e36:
		return ("%.2e" % value).replace("+", "")
	var suffixes := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
	var v := value
	var idx := 0
	while v >= 1000.0 and idx < suffixes.size() - 1:
		v /= 1000.0
		idx += 1
	if idx == 0:
		return str(int(v))
	if v < 10.0:
		return _trim_decimal_value("%.2f%s" % [v, suffixes[idx]])
	if v < 100.0:
		return _trim_decimal_value("%.1f%s" % [v, suffixes[idx]])
	return "%.0f%s" % [v, suffixes[idx]]


static func _trim_decimal_value(text: String) -> String:
	var suffix := ""
	for i in range(text.length()):
		var ch := text.substr(i, 1)
		if ch < "0" or ch > "9":
			if ch == ".":
				continue
			suffix = text.substr(i)
			text = text.substr(0, i)
			break
	text = text.rstrip("0").rstrip(".")
	return text + suffix


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


static func _add_drift_particles(parent: Node3D, position: Vector3, color: Color, amount: int) -> void:
	var particles := CPUParticles3D.new()
	particles.name = "DriftStars"
	particles.position = position
	particles.amount = amount
	particles.lifetime = 2.2
	particles.one_shot = false
	particles.explosiveness = 0.1
	particles.preprocess = 1.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.55
	particles.direction = Vector3(0.0, 0.2, 0.0)
	particles.spread = 180.0
	particles.gravity = Vector3(0.0, 0.02, 0.0)
	particles.initial_velocity_min = 0.02
	particles.initial_velocity_max = 0.10
	particles.scale_amount_min = 0.022
	particles.scale_amount_max = 0.045
	particles.color = color
	particles.mesh = LowPoly.sphere(1.0, 4, 2)
	particles.material_override = LowPoly.material(color, 0.0, 0.2, color, 2.2, true)
	particles.emitting = true
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(particles)
