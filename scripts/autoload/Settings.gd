extends Node
## Persistent (disk-backed) user preferences: master audio volume (0-100)
## and windowed resolution (1080p/1440p/2160p), both editable from
## MainMenu's SettingsMenu overlay. Separate from Progress.gd on purpose -
## these are device/display preferences, not player progression. Registered
## ahead of Music.gd in project.godot so the saved volume is already on the
## Master bus before the menu track starts playing.
##
## Volume drives AudioServer's "Master" bus gain directly (never its mute
## flag) so it stays independent of HUD.gd's own pause-mute, which toggles
## that same bus's mute flag - the two would otherwise fight over volume=0
## vs unpausing.

signal volume_changed(value: int)
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
var resolution: String = DEFAULT_RESOLUTION

func _ready() -> void:
	load_data()
	_apply_volume()
	_apply_resolution()

func set_master_volume(value: int) -> void:
	master_volume = clampi(value, 0, 100)
	_apply_volume()
	save_data()
	volume_changed.emit(master_volume)

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
	var res: String = str(parsed.get("resolution", DEFAULT_RESOLUTION))
	resolution = res if RESOLUTIONS.has(res) else DEFAULT_RESOLUTION
