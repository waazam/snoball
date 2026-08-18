extends Node
## Procedurally-synthesized (see audio/footsteps/ - no external SFX pack,
## same "build it in code/assets" spirit as the rest of the game's visuals)
## positional footstep one-shots for the player and every walking enemy,
## plus a continuous slide loop for the snowman (no legs to step with).
##
## Every sound plays through a pooled AudioStreamPlayer3D (see
## _acquire_player) on the "Footsteps" bus (Settings.gd owns that bus's
## volume/existence, driven by its own 0-100 setting) so Godot's own distance
## attenuation/max_distance cutoff does the "only audible within range" and
## "bigger enemy = wider range" work for free - callers (Enemy.gd/Player.gd)
## just pass a range per type, no manual distance math needed here.

const SOUNDS := {
	"player": "res://audio/footsteps/player_soft.wav",
	"elf": "res://audio/footsteps/player_soft.wav",
	"reindeer": "res://audio/footsteps/reindeer_clop.wav",
	"santa": "res://audio/footsteps/santa_thump.wav",
	"yeti": "res://audio/footsteps/yeti_thump.wav",
	"snowman_slide": "res://audio/footsteps/snowman_slide.wav",
}

# unit_size as a fraction of max_distance: keeps footsteps at full volume
# for the first chunk of that range instead of falling off within the
# first step or two, then rolling off over the rest of it.
const RANGE_TO_UNIT_SIZE := 0.12

var _streams: Dictionary = {}  # kind (String) -> AudioStream, loaded once

# Footstep frequency scales directly with how many enemies are alive and
# moving - at high wave counts that's easily 100+ enemies each stepping
# several times a second. play_step() used to spin up a brand-new
# AudioStreamPlayer3D (RenderingServer/AudioServer node creation, torn back
# down a fraction of a second later) for every single step, which turned
# into a steady stream of node churn exactly on the path that scales worst
# with wave number. A small pool of reusable players removes that churn:
# each one is created once, then recycled via _release_player on `finished`
# instead of being freed. MAX_POOL_SIZE caps how many footsteps can sound at
# once - past that, a step is just silently skipped (only matters in
# extreme crowds where a few missed thumps are inaudible anyway).
const MAX_POOL_SIZE := 24

var _pool: Array[AudioStreamPlayer3D] = []
var _active_count: int = 0

func _ready() -> void:
	for kind in SOUNDS:
		var stream: AudioStream = load(SOUNDS[kind])
		if kind == "snowman_slide" and stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_streams[kind] = stream

## One-shot footstep/thump at `pos`, inaudible past `max_distance`.
## `pitch`/`volume_db` let each caller add its own per-type character/jitter
## on top of the shared sample for that kind.
func play_step(kind: String, pos: Vector3, max_distance: float, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _streams.get(kind)
	if stream == null:
		return
	var player := _acquire_player()
	if player == null:
		return
	player.stream = stream
	player.bus = "Footsteps"
	player.max_distance = max_distance
	player.unit_size = max_distance * RANGE_TO_UNIT_SIZE
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.position = pos
	player.play()

## Reuses an idle pooled player if one's free; otherwise creates a new one
## (up to MAX_POOL_SIZE, permanently parented here so it survives run
## resets) and wires its `finished` signal once, for life, straight to
## _release_player - reused players never need to reconnect it.
func _acquire_player() -> AudioStreamPlayer3D:
	if not _pool.is_empty():
		return _pool.pop_back()
	if _active_count >= MAX_POOL_SIZE:
		return null
	_active_count += 1
	var player := AudioStreamPlayer3D.new()
	add_child(player)
	player.finished.connect(_release_player.bind(player))
	return player

func _release_player(player: AudioStreamPlayer3D) -> void:
	_pool.append(player)

## Configured-but-not-playing AudioStreamPlayer3D for the snowman's
## continuous slide loop - the caller (EnemySnowman.gd, via Enemy.gd's
## shared _update_slide_audio) parents it under the moving body itself so
## position tracks automatically, then starts/stops .playing as it
## starts/stops moving, instead of one-shotting a new player per call like
## play_step does.
func make_slide_player(max_distance: float, volume_db: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = _streams.get("snowman_slide")
	player.bus = "Footsteps"
	player.max_distance = max_distance
	player.unit_size = max_distance * RANGE_TO_UNIT_SIZE
	player.volume_db = volume_db
	return player
