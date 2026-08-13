extends Node
## Procedurally-synthesized (see audio/footsteps/ - no external SFX pack,
## same "build it in code/assets" spirit as the rest of the game's visuals)
## positional footstep one-shots for the player and every walking enemy,
## plus a continuous slide loop for the snowman (no legs to step with).
##
## Every sound plays through a short-lived AudioStreamPlayer3D on the
## "Footsteps" bus (Settings.gd owns that bus's volume/existence, driven by
## its own 0-100 setting) so Godot's own distance attenuation/max_distance
## cutoff does the "only audible within range" and "bigger enemy = wider
## range" work for free - callers (Enemy.gd/Player.gd) just pass a range
## per type, no manual distance math needed here.

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
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = "Footsteps"
	player.max_distance = max_distance
	player.unit_size = max_distance * RANGE_TO_UNIT_SIZE
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.position = pos
	get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

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
