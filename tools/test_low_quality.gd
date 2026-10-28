extends Node

## Dev-only low-quality smoke test and screenshot.
## godot --headless --path . tools/test_low_quality.tscn

var _failures: int = 0
var _previous_quality: int = 1


func _ready() -> void:
	_previous_quality = AudioManager.graphics_quality
	# Set in memory only; do not persist a test setting to the player's config.
	AudioManager.graphics_quality = 0
	SaveManager.pending_offline = 0.0
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		get_tree().quit(1)
		return
	add_child(packed.instantiate())
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var base := get_tree().root.find_child("BaseScreen", true, false)
	if base == null:
		push_error("BaseScreen not found")
		get_tree().quit(1)
		return
	var world: BaseWorld = base.get("world") as BaseWorld
	var world_env := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_check(world_env != null and not world_env.environment.glow_enabled, "low: environment glow disabled")

	GameState.slots[0] = 1
	base.call("_refresh_all_slots")
	await get_tree().create_timer(0.2).timeout
	var bombs := world.find_children("Bomb_*", "Node3D", true, false)
	var shadow_ok := true
	var particles_ok := true
	for node in bombs:
		var blob := node.get_node_or_null("BlobShadow") as Node3D
		if blob != null and blob.visible:
			shadow_ok = false
		for particle_node in node.find_children("*", "CPUParticles3D", true, false):
			var particles := particle_node as CPUParticles3D
			if particles != null and (particles.visible or particles.emitting):
				particles_ok = false
	_check(shadow_ok, "low: blob shadows hidden")
	_check(particles_ok, "low: bomb particles hidden")

	if DisplayServer.get_name() != "headless":
		var image := get_viewport().get_texture().get_image()
		if image != null:
			image.save_png("user://step8_low.png")

	AudioManager.graphics_quality = _previous_quality
	if _failures == 0:
		print("LOW QUALITY TEST: PASS")
		get_tree().quit(0)
	else:
		print("LOW QUALITY TEST: FAIL (%d)" % _failures)
		get_tree().quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok  ", label)
	else:
		_failures += 1
		push_error("  FAIL  " + label)
