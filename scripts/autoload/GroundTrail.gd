extends Node
## Spawns small fading ground decals - used for the piss-ball's yellow
## footprints and the bleed effect's blood trail. Each decal is a flat,
## unshaded quad laid on the ground that sits for most of its lifetime
## then fades out and frees itself.

func spawn(pos: Vector3, color: Color, lifetime: float) -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)
	quad.orientation = PlaneMesh.FACE_Y
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mi.material_override = mat
	get_tree().current_scene.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.02, 0)
	mi.rotation.y = randf() * TAU
	var tw := mi.create_tween()
	tw.tween_interval(lifetime * 0.6)
	tw.tween_property(mat, "albedo_color:a", 0.0, lifetime * 0.4)
	tw.tween_callback(mi.queue_free)
