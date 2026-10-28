class_name Bomb
extends Node3D

## Behaviour component shared by every bomb tier: gentle bobbing, glow pulsing,
## spinner rings, color-shifting cores and the billboard tier label.

var tier: int = 1
var low_quality: bool = false

var _bob: Node3D
var _glow_nodes: Array[Dictionary] = []
var _spinners: Array[Dictionary] = []
var _hue_materials: Array[StandardMaterial3D] = []
var _shadow: Node3D
var _time: float = 0.0
var _phase: float = 0.0
var _idle_started: bool = false


func setup(tier_number: int, quality_low: bool) -> void:
	tier = tier_number
	low_quality = quality_low
	_phase = randf() * TAU
	_shadow = get_node_or_null("BlobShadow") as Node3D
	if _shadow != null:
		_shadow.visible = not low_quality
	if low_quality:
		for node in find_children("*", "CPUParticles3D", true, false):
			var particles := node as CPUParticles3D
			if particles != null:
				particles.emitting = false
				particles.visible = false
	if is_inside_tree():
		_start_idle()


func register_glow(node: Node3D) -> void:
	if node != null:
		_glow_nodes.append({"node": node, "base": node.scale, "phase": randf() * TAU})


func register_spinner(node: Node3D, axis: Vector3, speed: float) -> void:
	if node != null:
		_spinners.append({"node": node, "axis": axis.normalized(), "speed": speed})


func register_hue_material(mat: StandardMaterial3D) -> void:
	if mat != null:
		_hue_materials.append(mat)


func _ready() -> void:
	_bob = get_node_or_null("Bob") as Node3D
	_start_idle()


func _start_idle() -> void:
	if _idle_started:
		return
	_idle_started = true
	_bob = get_node_or_null("Bob") as Node3D
	if _bob == null:
		return
	# Looping gentle bob. Random start offset keeps a board of bombs from moving
	# in lockstep.
	var start := randf_range(0.02, 0.11)
	_bob.position.y = start
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(_bob, "position:y", 0.13, 1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_bob, "position:y", 0.01, 1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	_time += delta
	for item in _glow_nodes:
		var node := item["node"] as Node3D
		if node == null:
			continue
		var base := item["base"] as Vector3
		var pulse := 1.0 + 0.07 * sin(_time * 2.1 + float(item["phase"]))
		node.scale = base * pulse
	for item in _spinners:
		var node := item["node"] as Node3D
		if node != null:
			node.rotate(item["axis"] as Vector3, float(item["speed"]) * delta)
	if not _hue_materials.is_empty():
		var hue := fmod(_time * 0.07, 1.0)
		for mat in _hue_materials:
			mat.emission = Color.from_hsv(hue, 0.68, 1.0)
			mat.albedo_color = Color.from_hsv(hue, 0.55, 1.0)
