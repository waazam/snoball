extends Node
## Background music - swaps between a main-menu track and a gameplay track
## as Game.state crosses the menu/run boundary, each looping continuously
## while it's the active one. Plays on the Master bus like everything else,
## so HUD.gd's pause-mute still silences whichever track is currently
## playing.

const MENU_TRACK_PATH := "res://audio/MainMenu.mp3"
const GAMEPLAY_TRACK_PATH := "res://audio/Menthall.mp3"
const MENU_VOLUME_DB := -16.0
const GAMEPLAY_VOLUME_DB := -6.0

var _player: AudioStreamPlayer
var _current_path: String = ""

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	Game.state_changed.connect(_on_state_changed)
	_on_state_changed(Game.state)

func _on_state_changed(new_state: int) -> void:
	var is_menu: bool = new_state == Game.State.MENU
	var path: String = MENU_TRACK_PATH if is_menu else GAMEPLAY_TRACK_PATH
	_player.volume_db = MENU_VOLUME_DB if is_menu else GAMEPLAY_VOLUME_DB
	if path == _current_path:
		return
	_current_path = path
	# Not `const X := preload(...)` - GDScript won't let you assign a
	# property (.loop below) through a const reference even though the
	# underlying Resource is mutable.
	var track: AudioStream = load(path)
	if track is AudioStreamMP3:
		track.loop = true
	_player.stream = track
	_player.play()
