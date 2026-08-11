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

## Soft muffled "poof" - the Standard Snowball's impact sound. A cushiony
## puff rather than a sharp crack.
func get_poof() -> AudioStreamWAV:
	if _poof_stream == null:
		_poof_stream = _build_poof()
	return _poof_stream

## Short "splat" impact, played on a normal hit.
func get_splat() -> AudioStreamWAV:
	if _splat_stream == null:
		_splat_stream = _build_splat(1.0, 22.0, 90.0, 0.6, 0.35)
	return _splat_stream

## A heavier, lower splat - used for the big-damage/explosion impacts.
func get_splat_heavy() -> AudioStreamWAV:
	if _splat_heavy_stream == null:
		_splat_heavy_stream = _build_splat(1.6, 14.0, 70.0, 0.75, 0.3)
	return _splat_heavy_stream

## Deep ominous drone-collapse, used only for the death ball's impact.
func get_implosion() -> AudioStreamWAV:
	if _implosion_stream == null:
		_implosion_stream = _build_implosion()
	return _implosion_stream

func _build_whoosh() -> AudioStreamWAV:
	var duration := 0.5
	var n := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var lp := 0.0
	for i in n:
		var noise: float = rng.randf_range(-1.0, 1.0)
		lp += 0.12 * (noise - lp)
		samples[i] = lp
	# Fade the head/tail down to (near) zero so the loop point doesn't click.
	var fade: int = int(MIX_RATE * 0.03)
	for i in fade:
		var g: float = float(i) / float(fade)
		samples[i] *= g
		samples[n - 1 - i] *= g
	return _to_wav(samples, true)

## Soft, round "woof" - very heavily low-passed noise (alpha 0.05, much
## smoother than the regular whoosh's 0.12) so almost no high-frequency
## content survives - no tonal whistle at all, just a breathy body. Gain-
## compensated since heavy smoothing drops the RMS a lot. Fades head/tail
## to zero for a click-free loop (unlike the whistle this replaced, this
## one has no convenient phase-integer trick since it's pure filtered
## noise, not a tone).
func _build_woof() -> AudioStreamWAV:
	var duration := 0.5
	var n := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var lp := 0.0
	for i in n:
		var noise: float = rng.randf_range(-1.0, 1.0)
		lp += 0.05 * (noise - lp)
		samples[i] = clampf(lp * 2.2, -1.0, 1.0)
	var fade: int = int(MIX_RATE * 0.04)
	for i in fade:
		var g: float = float(i) / float(fade)
		samples[i] *= g
		samples[n - 1 - i] *= g
	return _to_wav(samples, true)

## Soft muffled "poof": heavily low-passed noise (no crackle/hiss) plus a
## gentle low thump underneath - a cushiony puff instead of a sharp crack,
## with a slower decay than a crack would use so it doesn't feel clipped.
func _build_poof() -> AudioStreamWAV:
	var duration := 0.22
	var n := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	for i in n:
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-t * 16.0)
		var noise: float = rng.randf_range(-1.0, 1.0)
		lp += 0.07 * (noise - lp)
		var thump: float = sin(TAU * 130.0 * t) * exp(-t * 20.0) * 0.5
		samples[i] = clampf(lp * 2.2 * env + thump, -1.0, 1.0)
	return _to_wav(samples, false)

## noise_alpha controls brightness (higher = less smoothed = crisper, less
## "deep"/muffled); thump_freq/thump_weight control how much low-frequency
## boom rides underneath the noise burst.
func _build_splat(intensity: float, decay: float, thump_freq: float, thump_weight: float, noise_alpha: float) -> AudioStreamWAV:
	var duration := 0.24
	var n := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var lp := 0.0
	for i in n:
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-t * decay) * intensity
		var noise: float = rng.randf_range(-1.0, 1.0)
		lp += noise_alpha * (noise - lp)
		var thump: float = sin(TAU * thump_freq * t) * exp(-t * 14.0) * thump_weight
		samples[i] = clampf(lp * env + thump, -1.0, 1.0)
	return _to_wav(samples, false)

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
