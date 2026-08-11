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
var _whistle_stream: AudioStreamWAV
var _pop_stream: AudioStreamWAV

## Looping "airborne" whoosh, played while a (non-silent) snowball flies.
func get_whoosh() -> AudioStreamWAV:
	if _whoosh_stream == null:
		_whoosh_stream = _build_whoosh()
	return _whoosh_stream

## Looping bottle-rocket whistle - the Standard Snowball's airborne sound.
func get_bottle_rocket_whistle() -> AudioStreamWAV:
	if _whistle_stream == null:
		_whistle_stream = _build_whistle()
	return _whistle_stream

## Sharp downward-chirp crack/pop - the Standard Snowball's impact sound.
func get_bottle_rocket_pop() -> AudioStreamWAV:
	if _pop_stream == null:
		_pop_stream = _build_pop()
	return _pop_stream

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

## A high, warbling whistle (bottle-rocket flight sound) built with a
## running phase accumulator (rather than a fixed sin(freq*t)) so the pitch
## can wobble via vibrato while staying phase-continuous. Loops seamlessly
## because base_freq*duration and lfo_freq*duration are both exact integers
## by construction: an integer carrier-cycle count means the waveform lines
## up sample-for-sample at the wrap, and an integer number of vibrato
## cycles means the sweep's net contribution to total phase is exactly
## zero (sin integrates to 0 over whole periods) - so nothing needs a fade
## to avoid a click.
func _build_whistle() -> AudioStreamWAV:
	var duration := 0.55
	var base_freq := 1100.0  # 1100 * 0.55 = 605 whole cycles
	var lfo_cycles := 3.0
	var lfo_freq: float = lfo_cycles / duration
	var sweep := 180.0
	var n := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t: float = float(i) / float(MIX_RATE)
		var vibrato: float = sin(TAU * lfo_freq * t)
		var freq: float = base_freq + sweep * vibrato
		phase += freq / MIX_RATE
		var tone: float = sin(TAU * phase)
		var noise: float = rng.randf_range(-1.0, 1.0)
		lp += 0.15 * (noise - lp)
		samples[i] = clampf(tone * 0.55 + lp * 0.12, -1.0, 1.0)
	return _to_wav(samples, true)

## Sharp crack: a fast noise burst plus a quick downward frequency chirp,
## much snappier than the regular splat - reads as a firework "pop" rather
## than a snow impact thud.
func _build_pop() -> AudioStreamWAV:
	var duration := 0.16
	var n := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t: float = float(i) / float(MIX_RATE)
		var env: float = exp(-t * 32.0)
		var noise: float = rng.randf_range(-1.0, 1.0)
		lp += 0.7 * (noise - lp)
		var crack_freq: float = lerpf(1400.0, 220.0, clampf(t / 0.08, 0.0, 1.0))
		phase += crack_freq / MIX_RATE
		var crack: float = sin(TAU * phase) * exp(-t * 28.0)
		samples[i] = clampf((lp * 0.55 + crack * 0.75) * env * 1.3, -1.0, 1.0)
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
