extends Node
## Spawns small fading ground decals - used for the piss-ball's yellow
## footprints and the bleed effect's blood trail. Each decal is a flat,
## unshaded quad laid on the ground that sits for most of its lifetime
## then fades out and frees itself.
##
## Visual pass: quads vary a little in size, land slightly transparent
## (stains soaked into snow, not paint chips sitting on it), and pop in
## with a quick settle-scale so each drip reads as landing rather than
## teleporting in. Same spawn(pos, color, lifetime) contract as always.

func spawn(pos: Vector3, color: Color, lifetime: float) -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var quad := QuadMesh.new()
	var s: float = randf_range(0.24, 0.34)
	quad.size = Vector2(s, s)
	quad.orientation = PlaneMesh.FACE_Y
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	var mat := StandardMaterial3D.new()
	var tint := color
	tint.a = minf(color.a, 0.85)  # soaked-in, lets the snow's vertex color breathe through
	mat.albedo_color = tint
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mi.material_override = mat
	get_tree().current_scene.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.02, 0)
	mi.rotation.y = randf() * TAU
	mi.scale = Vector3(0.55, 1.0, 0.55)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(lifetime * 0.6 - 0.18, 0.0))
	tw.tween_property(mat, "albedo_color:a", 0.0, lifetime * 0.4)
	tw.tween_callback(mi.queue_free)
