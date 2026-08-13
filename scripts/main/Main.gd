extends Node3D
## Top-level orchestrator: owns the state machine that moves the game
## between the main menu, an active run (arena + player + waves), the
## between-wave upgrade screen, and the game-over screen.

const ARENA_SCENE := preload("res://scenes/world/Arena.tscn")
const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const NEXT_WAVE_DELAY := 2.5

@onready var world: Node3D = $World
@onready var hud: CanvasLayer = $HUD
@onready var upgrade_screen: CanvasLayer = $UpgradeScreen
@onready var main_menu: CanvasLayer = $MainMenu
@onready var game_over_screen: CanvasLayer = $GameOverScreen

var arena: Node3D = null
var player: CharacterBody3D = null
var wave_manager: Node = null
var _next_wave_timer: float = -1.0

func _ready() -> void:
	hud.visible = false
	upgrade_screen.visible = false
	game_over_screen.visible = false
	main_menu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	main_menu.start_pressed.connect(_on_start_pressed)
	upgrade_screen.upgrade_selected.connect(_on_upgrade_selected)
	game_over_screen.restart_pressed.connect(_on_restart_pressed)
	game_over_screen.menu_pressed.connect(_on_menu_pressed)
	Game.player_died.connect(_on_player_died)

func _process(delta: float) -> void:
	if _next_wave_timer >= 0.0:
		_next_wave_timer -= delta
		if _next_wave_timer <= 0.0:
			_next_wave_timer = -1.0
			_start_next_wave()
	if Input.is_action_just_pressed("pause") and (Game.state == Game.State.PLAYING or Game.state == Game.State.PAUSED):
		_toggle_pause()

func _toggle_pause() -> void:
	if Game.state == Game.State.PLAYING:
		Game.set_state(Game.State.PAUSED)
		hud.set_paused(true)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif Game.state == Game.State.PAUSED:
		Game.set_state(Game.State.PLAYING)
		hud.set_paused(false)
		_capture_mouse_if_desktop()

# --- Run lifecycle -------------------------------------------------------
func _on_start_pressed() -> void:
	main_menu.visible = false
	_begin_run()

func _begin_run() -> void:
	Game.reset_run()
	_spawn_arena_and_player()
	hud.visible = true
	game_over_screen.visible = false
	_capture_mouse_if_desktop()
	Game.set_state(Game.State.PLAYING)
	Game.advance_wave()
	wave_manager.start_wave(Game.wave)

func _spawn_arena_and_player() -> void:
	if player:
		player.queue_free()
		player = null
	if arena:
		arena.queue_free()
		arena = null
	arena = ARENA_SCENE.instantiate()
	world.add_child(arena)
	wave_manager = arena.get_node("WaveManager")
	wave_manager.wave_cleared.connect(_on_wave_cleared)
	player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	player.global_position = arena.get_node("PlayerSpawn").global_position
	_apply_arena_lighting_overrides()

func _apply_arena_lighting_overrides() -> void:
	# Visual-only: Main.tscn owns the "Alpenglow Dusk" lighting rig (its
	# WorldEnvironment + DuskSun key / MoonFill fill lights). If the arena
	# scene still carries its own legacy sun, hide it so the world isn't
	# double-lit by two shadowed directionals. Main's WorldEnvironment is the
	# first in tree order, so it stays the active environment regardless.
	if arena == null:
		return
	var legacy_sun := arena.get_node_or_null("Sun")
	if legacy_sun is DirectionalLight3D:
		legacy_sun.visible = false

func _on_wave_cleared(_wave: int) -> void:
	if Game.state != Game.State.PLAYING:
		return
	Progress.report_wave_cleared(Game.wave)
	Game.set_state(Game.State.UPGRADE)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	upgrade_screen.open()

func _on_upgrade_selected() -> void:
	Game.set_state(Game.State.PLAYING)
	_capture_mouse_if_desktop()
	_next_wave_timer = NEXT_WAVE_DELAY

func _capture_mouse_if_desktop() -> void:
	# Pointer lock is a desktop-mouse concept; skip it on touchscreens where
	# there's no cursor to hide/lock in the first place.
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _start_next_wave() -> void:
	Game.advance_wave()
	wave_manager.start_wave(Game.wave)

func _on_player_died() -> void:
	Game.set_state(Game.State.GAME_OVER)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if wave_manager:
		wave_manager.clear_all_enemies()
	game_over_screen.show_results()

func _on_restart_pressed() -> void:
	game_over_screen.visible = false
	_begin_run()

func _on_menu_pressed() -> void:
	game_over_screen.visible = false
	hud.visible = false
	if player:
		player.queue_free()
		player = null
	if arena:
		arena.queue_free()
		arena = null
	wave_manager = null
	Game.reset_run()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main_menu.visible = true
