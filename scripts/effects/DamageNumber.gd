extends Label3D
## A floating damage number that pops in above an enemy's head, arcs up and
## sideways, and fades out with a slight shrink. Built and configured
## entirely in code (see Enemy.gd's _spawn_damage_number) - no separate
## scene needed, same approach as HatVisuals.gd for hats.
##
## Palette (ART_DIRECTION): text FX_DAMAGE #FF6B4A on a #111527 outline so
## the numbers carry the same warm-threat ember tone as the rest of the FX
## family instead of plain white-on-black.

const RISE_HEIGHT := 0.9
const LIFETIME := 0.7
const POP_SCALE := 1.45
const DRIFT_RANGE := 0.3
const TEXT_COLOR := Color("#FF6B4A")
const OUTLINE_COLOR := Color("#111527")

func setup(amount: float) -> void:
	text = str(int(round(amount)))
	font_size = 64
	outline_size = 16
	modulate = Color(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b, 1.0)
	outline_modulate = Color(OUTLINE_COLOR.r, OUTLINE_COLOR.g, OUTLINE_COLOR.b, 1.0)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	position.x += randf_range(-0.15, 0.15)  # so consecutive hits don't stack exactly on top of each other
	scale = Vector3.ONE * 0.3

	# Punchy pop: overshoot past full size, then settle.
	var pop_tw := create_tween()
	pop_tw.tween_property(self, "scale", Vector3.ONE * POP_SCALE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tw.tween_property(self, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Arc: the rise eases OUT (fast launch, slows at top) while a random
	# sideways drift eases IN (slow start, speeds up) - together the number
	# tips over sideways like a tossed coin instead of elevator-ing straight
	# up.
	var rise_tw := create_tween()
	rise_tw.tween_property(self, "position:y", position.y + RISE_HEIGHT, LIFETIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var drift_tw := create_tween()
	drift_tw.tween_property(self, "position:x", position.x + randf_range(-DRIFT_RANGE, DRIFT_RANGE), LIFETIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# modulate and outline_modulate are separate colors on Label3D, so both
	# need to be faded together or the outline would hang around alone. A
	# parallel shrink sells the "spent" feel as it dies.
	var fade_tw := create_tween()
	fade_tw.tween_interval(LIFETIME * 0.5)
	fade_tw.tween_property(self, "modulate:a", 0.0, LIFETIME * 0.5)
	fade_tw.parallel().tween_property(self, "outline_modulate:a", 0.0, LIFETIME * 0.5)
	fade_tw.parallel().tween_property(self, "scale", Vector3.ONE * 0.75, LIFETIME * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade_tw.tween_callback(queue_free)
