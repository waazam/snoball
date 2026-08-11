extends Node
## Procedurally-synthesized sound effects - this project has no imported
## audio assets, so short PCM clips are built once in code (simple noise +
## envelope DSP) and cached as AudioStreamWAV resources that every Snowball
## instance reuses. Same "everything is code-built, nothing imported"
## approach as HatVisuals.gd/LowPolySky.gd etc., just for audio instead of
## meshes.

const MIX_RATE := 22050  # plenty for short SFX, keeps buffers small

var _whoosh_stream: AudioStreamWAV
var _splat_stream: AudioStreamWAV
var _splat_heavy_stream: AudioStreamWAV
var _implosion_stream: AudioStreamWAV
var _woof_stream: AudioStreamWAV
var _poof_stream: AudioStreamWAV

## Looping "airborne" whoosh, played while a (non-silent) snowball flies.
func get_whoosh() -> AudioStreamWAV:
	if _whoosh_stream == null:
		_whoosh_stream = _build_whoosh()
	return _whoosh_stream

## Looping soft breathy "woof" - the Standard Snowball's airborne sound. No
## tonal whistle, just a heavily-smoothed, round gust of air.
func get_woof() -> AudioStreamWAV:
	if _woof_stream == null:
		_woof_stream = _build_woof()
	return _woof_stream

## Soft "pillow hitting crunchy snow" - the Standard Snowball's impact
## sound. A cushiony puff rather than a sharp crack.
func get_poof() -> AudioStreamWAV:
	if _poof_stream == null:
		_poof_stream = _build_poof()
	return _poof_stream

## "Pillow hitting crunchy snow" impact, played on a normal hit.
func get_splat() -> AudioStreamWAV:
	if _splat_stream == null:
		_splat_stream = _build_splat(1.0, 15.0, 0.26)
	return _splat_stream

## A heavier, lower version of the same impact - used for the big-damage/
## explosion impacts.
func get_splat_heavy() -> AudioStreamWAV:
	if _splat_heavy_stream == null:
		_splat_heavy_stream = _build_splat(1.6, 9.0, 0.2)
	return _splat_heavy_stream

## Deep ominous drone-collapse, used only for the death ball's impact.
func get_implosion() -> AudioStreamWAV:
	if _implosion_stream == null:
		_implosion_stream = _build_implosion()
	return _implosion_stream

## "Pillow whoosh" (brighter variant, other snowball types) - heavily
## low-passed noise with a slow, gentle amplitude tremolo layered on top so
## it breathes a little instead of sitting at a flat drone, like something
## soft tumbling through the air rather than a sharp gust.
func _build_whoosh() -> AudioStreamWAV:
	var duration := 0.5
	var n := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var lp := 0.0
	for i in n:
		var t: float = float(i) / float(MIX_RATE)
		var noise: float = rng.randf_range(-1.0, 1.0)
		lp += 0.08 * (noise - lp)
		var trem: float = 1.0 + 0.12 * sin(TAU * 4.0 * t)
		samples[i] = lp * trem
	# Fade the head/tail down to (near) zero so the loop point doesn't click.
	var fade: int = int(MIX_RATE * 0.03)
	for i in fade:
		var g: float = float(i) / float(fade)
		samples[i] *= g
		samples[n - 1 - i] *= g
	return _to_wav(samples, true)

## "Pillow whoosh" - the Standard Snowball's airborne sound: very heavily
## low-passed noise (softer than the general whoosh above) with the same
## gentle tremolo, so it reads as a pillow tumbling/fluttering through the
## air rather than a harsh gust. Gain-compensated since the heavy smoothing
## drops the RMS a lot. Fades head/tail to zero for a click-free loop.
func _build_woof() -> AudioStreamWAV:
	var duration := 0.5
	var n := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var lp := 0.0
	for i in n:
		var t: float = float(i) / float(MIX_RATE)
		var noise: float = rng.randf_range(-1.0, 1.0)
		lp += 0.045 * (noise - lp)
		var trem: float = 1.0 + 0.15 * sin(TAU * 3.4 * t)
		samples[i] = clampf(lp * 2.3 * trem, -1.0, 1.0)
	var fade: int = int(MIX_RATE * 0.04)
	for i in fade:
		var g: float = float(i) / float(fade)
		samples[i] *= g
		samples[n - 1 - i] *= g
	return _to_wav(samples, true)

## Soft "pillow hitting crunchy snow": a heavily low-passed noise body with
## a brief fade-in (so it "whumpfs" in rather than popping like a gunshot)
## plus a scatter of tiny crackle grains layered on top for the snow-crunch
## texture. The Standard Snowball's impact sound.
func _build_poof() -> AudioStreamWAV:
	var duration := 0.3
	var n := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	var attack: int = int(MIX_RATE * 0.015)
	for i in n:
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-t * 12.0)
		if i < attack:
			env *= float(i) / float(attack)
		var noise: float = rng.randf_range(-1.0, 1.0)
		lp += 0.06 * (noise - lp)
		samples[i] = clampf(lp * 2.3 * env, -1.0, 1.0)
	samples = _add_crunch(samples, rng, 0.18, 24)
	return _to_wav(samples, false)

## Same soft "pillow hitting crunchy snow" shape as _build_poof, but with
## intensity/decay/noise_alpha so heavier hits still land bigger (more
## sustain, more crunch) without turning into a percussive crack.
## noise_alpha controls brightness (higher = crisper/less muffled).
func _build_splat(intensity: float, decay: float, noise_alpha: float) -> AudioStreamWAV:
	var duration := 0.34
	var n := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var lp := 0.0
	var attack: int = int(MIX_RATE * 0.018)
	for i in n:
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-t * decay) * intensity
		if i < attack:
			env *= float(i) / float(attack)
		var noise: float = rng.randf_range(-1.0, 1.0)
		lp += noise_alpha * (noise - lp)
		samples[i] = clampf(lp * env, -1.0, 1.0)
	samples = _add_crunch(samples, rng, 0.22, int(20.0 * intensity) + 14)
	return _to_wav(samples, false)

## Scatters a handful of tiny, quickly-decaying noise "grains" over the
## first part of an impact sample - the crackly, granular texture of snow
## compacting underfoot - layered on top of the softer body above so
## impacts read as "pillow hitting crunchy snow" instead of a bare thump.
## Returns the mutated array (rather than mutating samples in place) so
## there's no reliance on PackedFloat32Array's by-reference-vs-by-value
## semantics across a function call - callers just do `samples =
## _add_crunch(samples, ...)`.
func _add_crunch(samples: PackedFloat32Array, rng: RandomNumberGenerator, span: float, grain_count: int) -> PackedFloat32Array:
	var n: int = samples.size()
	var span_samples: int = maxi(1, int(n * span))
	for g in grain_count:
		var start: int = rng.randi_range(0, span_samples - 1)
		var grain_len: int = mini(rng.randi_range(50, 200), n - start)
		var amp: float = rng.randf_range(0.12, 0.35)
		for j in grain_len:
			var decay: float = exp(-float(j) / float(grain_len) * 7.0)
			var idx: int = start + j
			samples[idx] = clampf(samples[idx] + rng.randf_range(-1.0, 1.0) * amp * decay, -1.0, 1.0)
	return samples

func _build_implosion() -> AudioStreamWAV:
	var duration := 0.55
	var n := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var lp := 0.0
	for i in n:
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-t * 5.0)
		var noise: float = rng.randf_range(-1.0, 1.0)
		lp += 0.08 * (noise - lp)
		var drone: float = sin(TAU * 55.0 * t + sin(t * 30.0)) * 0.5
		samples[i] = clampf((lp * 0.6 + drone) * env, -1.0, 1.0)
	return _to_wav(samples, false)

func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: int = clampi(int(samples[i] * 32767.0), -32768, 32767)
		bytes.encode_s16(i * 2, v)
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size() - 1
	return wav
