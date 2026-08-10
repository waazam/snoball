extends Label3D
## A floating damage number that pops in above an enemy's head, rises, and
## fades out. Built and configured entirely in code (see
## Enemy.gd's _spawn_damage_number) - no separate scene needed, same
## approach as HatVisuals.gd for hats.

const RISE_HEIGHT := 0.9
const LIFETIME := 0.7
const POP_SCALE := 1.3

func setup(amount: float) -> void:
	text = str(int(round(amount)))
	font_size = 64
	outline_size = 14
	modulate = Color(1, 1, 1)
	outline_modulate = Color(0, 0, 0, 1)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	position.x += randf_range(-0.15, 0.15)  # so consecutive hits don't stack exactly on top of each other
	scale = Vector3.ONE * 0.4

	var pop_tw := create_tween()
	pop_tw.tween_property(self, "scale", Vector3.ONE * POP_SCALE, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tw.tween_property(self, "scale", Vector3.ONE, 0.1)

	var rise_tw := create_tween()
	rise_tw.tween_property(self, "position:y", position.y + RISE_HEIGHT, LIFETIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# modulate and outline_modulate are separate colors on Label3D, so both
	# need to be faded together or the outline would hang around alone.
	var fade_tw := create_tween()
	fade_tw.tween_interval(LIFETIME * 0.5)
	fade_tw.tween_property(self, "modulate:a", 0.0, LIFETIME * 0.5)
	fade_tw.parallel().tween_property(self, "outline_modulate:a", 0.0, LIFETIME * 0.5)
	fade_tw.tween_callback(queue_free)
