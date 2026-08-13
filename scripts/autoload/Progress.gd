extends Node
## Persistent (disk-backed) player progression - separate from Game.gd on
## purpose, since Game.reset_run() wipes its state every run but unlocks and
## the equipped snowball must survive a restart (even relaunching the game).
## best_wave_cleared is an all-time high-water mark across every run ever
## played; report_wave_cleared only ever raises it. Registered as an
## autoload BEFORE Game in project.godot, so its save file is already loaded
## by the time Game._ready()/reset_run() reads equipped_snowball.

signal equipped_changed(id: String)

const SAVE_PATH := "user://progress.json"

var best_wave_cleared: int = 0
var equipped_snowball: String = "standard"

func _ready() -> void:
	load_data()

## True for the starter ball or any type whose unlock_wave has been reached.
func is_unlocked(id: String) -> bool:
	return SnowballDB.get_unlock_wave(id) <= best_wave_cleared

## Called when a wave is cleared (see Main._on_wave_cleared) - only raises
## the high-water mark, never lowers it.
func report_wave_cleared(wave: int) -> void:
	if wave > best_wave_cleared:
		best_wave_cleared = wave
		save_data()

## Equips id if unlocked; no-op (returns false) otherwise, e.g. a stale
## button click racing a reset. Permanent until the next equip() call.
func equip(id: String) -> bool:
	if not is_unlocked(id):
		return false
	equipped_snowball = id
	emit_signal("equipped_changed", id)
	save_data()
	return true

func save_data() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"best_wave_cleared": best_wave_cleared,
		"equipped_snowball": equipped_snowball,
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
	best_wave_cleared = int(parsed.get("best_wave_cleared", 0))
	var equipped: String = str(parsed.get("equipped_snowball", "standard"))
	# Guard against a corrupt/edited save handing us an id that isn't
	# actually unlocked (or doesn't exist) - fall back to the starter ball.
	if equipped in SnowballDB.TYPES and is_unlocked(equipped):
		equipped_snowball = equipped
