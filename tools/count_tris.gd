extends SceneTree

## Dev-only triangle budget report.
## godot --headless --path . --script tools/count_tris.gd

func _init() -> void:
	var total := 0
	var worst_tier := 0
	var worst_tris := 0
	for tier in range(1, 101):
		var bomb := BombFactory.build(tier, false)
		var triangles := 0
		for node in bomb.find_children("*", "MeshInstance3D", true, false):
			var instance := node as MeshInstance3D
			if instance != null and instance.mesh != null:
				triangles += int(instance.mesh.get_faces().size() / 3)
		if triangles > worst_tris:
			worst_tris = triangles
			worst_tier = tier
		if tier <= 15 or tier in [16, 25, 50, 75, 99, 100]:
			print("Tier %3d: %4d triangles" % [tier, triangles])
		total += triangles
		bomb.free()
	print("TOTAL for 100 tiers: ", total)
	print("Worst tier: %d at %d triangles" % [worst_tier, worst_tris])
	quit(0)
