class_name LowPoly
extends RefCounted

## Shared low-poly primitive factory.
##
## All meshes and most materials are cached by their parameters so that every
## bomb of the same tier (and every slot pad) reuses the same GPU resources.
## Static caches live for the whole session; call `clear_cache()` only for tools.

static var _mesh_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}


static func clear_cache() -> void:
	_mesh_cache.clear()
	_mat_cache.clear()


# --- Meshes -----------------------------------------------------------------

static func sphere(radius: float, segments: int = 10, rings: int = 6, hemisphere: bool = false) -> SphereMesh:
	var key := "sph_%.4f_%d_%d_%s" % [radius, segments, rings, str(hemisphere)]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as SphereMesh
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	mesh.is_hemisphere = hemisphere
	_mesh_cache[key] = mesh
	return mesh


static func cylinder(top_radius: float, bottom_radius: float, height: float, segments: int = 10) -> CylinderMesh:
	var key := "cyl_%.4f_%.4f_%.4f_%d" % [top_radius, bottom_radius, height, segments]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as CylinderMesh
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	_mesh_cache[key] = mesh
	return mesh


static func capsule(radius: float, height: float, segments: int = 10, rings: int = 5) -> CapsuleMesh:
	var key := "cap_%.4f_%.4f_%d_%d" % [radius, height, segments, rings]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as CapsuleMesh
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = rings
	_mesh_cache[key] = mesh
	return mesh


static func box(size: Vector3) -> BoxMesh:
	var key := "box_%.4f_%.4f_%.4f" % [size.x, size.y, size.z]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as BoxMesh
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh_cache[key] = mesh
	return mesh


static func prism(size: Vector3) -> PrismMesh:
	var key := "pri_%.4f_%.4f_%.4f" % [size.x, size.y, size.z]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as PrismMesh
	var mesh := PrismMesh.new()
	mesh.size = size
	_mesh_cache[key] = mesh
	return mesh


static func torus(ring_radius: float, tube_radius: float, rings: int = 10, ring_segments: int = 6) -> TorusMesh:
	var key := "tor_%.4f_%.4f_%d_%d" % [ring_radius, tube_radius, rings, ring_segments]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as TorusMesh
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(ring_radius - tube_radius, 0.01)
	mesh.outer_radius = ring_radius + tube_radius
	mesh.rings = rings
	mesh.ring_segments = ring_segments
	_mesh_cache[key] = mesh
	return mesh


# --- Materials --------------------------------------------------------------

static func material(
	color: Color,
	metallic: float = 0.0,
	roughness: float = 0.55,
	emission: Color = Color.BLACK,
	emission_energy: float = 0.0,
	unshaded: bool = false,
	alpha: float = 1.0,
	cull_disabled: bool = false
) -> StandardMaterial3D:
	var key := "mat_%s_%.2f_%.2f_%s_%.2f_%s_%.2f_%s" % [
		color.to_html(), metallic, roughness, emission.to_html(),
		emission_energy, str(unshaded), alpha, str(cull_disabled)
	]
	if _mat_cache.has(key):
		return _mat_cache[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = alpha
	if cull_disabled:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[key] = mat
	return mat


## A unique material for one-off effects that fade or change color.
static func material_unique(
	color: Color,
	emission: Color = Color.BLACK,
	emission_energy: float = 0.0,
	unshaded: bool = true,
	alpha: float = 1.0
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_color.a = alpha
	mat.metallic = 0.0
	mat.roughness = 0.4
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


# --- Scene helpers ----------------------------------------------------------

static func add_mesh(
	parent: Node,
	mesh: Mesh,
	mat: Material,
	position: Vector3 = Vector3.ZERO,
	rotation_degrees: Vector3 = Vector3.ZERO,
	scale: Vector3 = Vector3.ONE,
	mesh_name: String = "Mesh"
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = position
	instance.rotation_degrees = rotation_degrees
	instance.scale = scale
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


static func blob_shadow(radius: float = 0.5) -> MeshInstance3D:
	var mat := material(Color(0.01, 0.02, 0.04, 0.26), 0.0, 1.0, Color.BLACK, 0.0, true, 0.26)
	var disc := MeshInstance3D.new()
	disc.name = "BlobShadow"
	disc.mesh = cylinder(radius, radius, 0.012, 12)
	disc.material_override = mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return disc


# --- Environment ------------------------------------------------------------

static func create_environment(glow_enabled: bool = true) -> WorldEnvironment:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color.html("#5BB8FF")
	sky_material.sky_horizon_color = Color.html("#BFE6FF")
	sky_material.sky_curve = 0.18
	sky_material.ground_bottom_color = Color.html("#9BE08A")
	sky_material.ground_horizon_color = Color.html("#BFE6FF")
	sky_material.sun_angle_max = 0.0
	sky_material.sun_curve = 0.1

	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.4
	env.glow_enabled = glow_enabled
	env.glow_intensity = 0.45
	env.glow_strength = 0.85
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	return world_env


static func create_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	return sun


static func create_camera(ortho_size: float = 26.0) -> Camera3D:
	var camera := Camera3D.new()
	camera.name = "IsoCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = ortho_size
	camera.position = Vector3(20.0, 20.0, 20.0)
	camera.rotation_degrees = Vector3(-35.0, 45.0, 0.0)
	camera.near = 0.1
	camera.far = 120.0
	camera.current = true
	return camera
