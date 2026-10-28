extends SceneTree

## Dev-only triangle budget report.
## godot --headless --path . --script tools/count_tris.gd

func _init() -> void:
	var total := 0
	for tier in range(1, 16):
		var bomb := BombFactory.build(tier, false)
		var triangles := 0
		for node in bomb.find_children("*", "MeshInstance3D", true, false):
			var instance := node as MeshInstance3D
			if instance != null and instance.mesh != null:
				triangles += int(instance.mesh.get_faces().size() / 3)
		print("Tier %2d: %4d triangles" % [tier, triangles])
		if tier in [4, 6, 15]:
			for node in bomb.find_children("*", "MeshInstance3D", true, false):
				var m := node as MeshInstance3D
				if m != null and m.mesh != null:
					print("   ", m.name, ": ", int(m.mesh.get_faces().size() / 3))
		total += triangles
		bomb.free()
	print("TOTAL: ", total)
	quit(0)
