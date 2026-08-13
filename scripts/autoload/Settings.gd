extends Node
## Persistent (disk-backed) user preferences: master music volume (0-100),
## footstep volume (0-100), and windowed resolution (1080p/1440p/2160p),
## all editable from MainMenu's SettingsMenu overlay. Separate from
## Progress.gd on purpose - these are device/display preferences, not
## player progression. Registered ahead of Music.gd/Footsteps.gd in
## project.godot so both are already at their saved volume before anything
## plays.
##
## Music volume drives AudioServer's "Master" bus gain directly (never its
## mute flag) so it stays independent of HUD.gd's own pause-mute, which
## toggles that same bus's mute flag - the two would otherwise fight over
## volume=0 vs unpausing. Footstep volume gets its own "Footsteps" bus
## (created here, routed into Master) so it's adjustable separately from
## music - pause-mute still silences it for free since it's downstream of
## Master.

signal volume_changed(value: int)
signal footsteps_volume_changed(value: int)
signal resolution_changed(key: String)

const SAVE_PATH := "user://settings.json"

const RESOLUTIONS := {
	"1080p": Vector2i(1920, 1080),
	"1440p": Vector2i(2560, 1440),
	"2160p": Vector2i(3840, 2160),
}
const DEFAULT_RESOLUTION := "1080p"
# Floor for volume=0 - inaudible without hitting linear_to_db(0)'s -inf.
const MIN_VOLUME_DB := -60.0

var master_volume: int = 100  # 0-100, UI-facing range
var footsteps_volume: int = 100  # 0-100, UI-facing range
var resolution: String = DEFAULT_RESOLUTION

func _ready() -> void:
	load_data()
	_apply_volume()
	_apply_footsteps_volume()
	_apply_resolution()

func set_master_volume(value: int) -> void:
	master_volume = clampi(value, 0, 100)
	_apply_volume()
	save_data()
	volume_changed.emit(master_volume)

func set_footsteps_volume(value: int) -> void:
	footsteps_volume = clampi(value, 0, 100)
	_apply_footsteps_volume()
	save_data()
	footsteps_volume_changed.emit(footsteps_volume)

func set_resolution(key: String) -> void:
	if not RESOLUTIONS.has(key):
		return
	resolution = key
	_apply_resolution()
	save_data()
	resolution_changed.emit(key)

func _apply_volume() -> void:
	var idx: int = AudioServer.get_bus_index("Master")
	if master_volume <= 0:
		AudioServer.set_bus_volume_db(idx, MIN_VOLUME_DB)
	else:
		AudioServer.set_bus_volume_db(idx, linear_to_db(master_volume / 100.0))

func _apply_footsteps_volume() -> void:
	var idx: int = _ensure_footsteps_bus()
	if footsteps_volume <= 0:
		AudioServer.set_bus_volume_db(idx, MIN_VOLUME_DB)
	else:
		AudioServer.set_bus_volume_db(idx, linear_to_db(footsteps_volume / 100.0))

## The project ships with only the default "Master" bus (see project.godot -
## no custom bus layout resource) - created here instead, entirely in code,
## same "nothing hand-authored that can be built procedurally" approach the
## rest of the game already follows. Idempotent: safe to call every launch.
func _ensure_footsteps_bus() -> int:
	var idx: int = AudioServer.get_bus_index("Footsteps")
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Footsteps")
		AudioServer.set_bus_send(idx, "Master")
	return idx

func _apply_resolution() -> void:
	var size: Vector2i = RESOLUTIONS.get(resolution, RESOLUTIONS[DEFAULT_RESOLUTION])
	var window: Window = get_window()
	window.size = size
	window.move_to_center()

func save_data() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"master_volume": master_volume,
		"footsteps_volume": footsteps_volume,
		"resolution": resolution,
	}))

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	master_volume = clampi(int(parsed.get("master_volume", 100)), 0, 100)
	footsteps_volume = clampi(int(parsed.get("footsteps_volume", 100)), 0, 100)
	var res: String = str(parsed.get("resolution", DEFAULT_RESOLUTION))
	resolution = res if RESOLUTIONS.has(res) else DEFAULT_RESOLUTION
