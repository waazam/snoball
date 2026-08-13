extends Node3D
## Standalone collision + movement + animation prototype for the player
## character model (see scripts/player/PlayerToyModel.gd for the actual
## clothed body - tan skin, black boots, blue jeans, green Christmas
## sweater). Open/run this scene directly (F6 in the editor, or
## `godot --path . "player character model/PlayerCharacterModelPrototype.tscn"`)
## to walk the real player around a simple flat floor, independent of the
## full Arena/wave/HUD setup, and confirm:
##   - the clothing geometry follows the baked Idle/Jog_Fwd/Sprint/Jump
##     animations correctly (PlayerToyModel.gd rides the same Skeleton3D
##     those clips animate, so every clothing piece should track bone-for-
##     bone exactly like the old coat-and-scarf look did);
##   - normal CharacterBody3D collision/movement/jumping/dashing against a
##     plain floor still behaves exactly as it does in the real game -
##     nothing about this prototype touches Player.gd's collision or
##     movement code, only PlayerToyModel.gd's cosmetic geometry/colors.
##
## Instances the real Player.tscn rather than a copy, so there's a single
## source of truth for the character and this prototype can never drift
## out of sync with the shipped game.

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")

func _ready() -> void:
	# Player.gd's _physics_process/_unhandled_input both gate on
	# Game.state == PLAYING, and _handle_auto_throw wants a clean baseline
	# from Game.reset_run() (same two calls Main.gd's _begin_run() makes) -
	# without them the player would just stand there ignoring input.
	Game.reset_run()
	Game.set_state(Game.State.PLAYING)
	var player: CharacterBody3D = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector3(0, 1.0, 0)
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	# Esc releases the mouse instead of pausing - there's no pause menu in
	# this standalone prototype - so testers can get their cursor back.
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
