extends Node
## Global run-state singleton. Holds everything that persists across a single
## roguelike run (health, wave, score, unlocked snowball types, upgrade
## stacks) and the signal bus the rest of the game listens to.

signal health_changed(current: float, max_health: float)
signal wave_changed(wave: int)
signal score_changed(score: int)
signal kills_changed(kills: int)
signal player_died
signal state_changed(new_state: int)
signal weapon_changed(id: String, tier: int)
signal upgrades_applied
signal upgrade_picked(title: String)

enum State { MENU, PLAYING, UPGRADE, PAUSED, GAME_OVER }

var state: int = State.MENU

# --- Run stats -------------------------------------------------------------
var wave: int = 0
var score: int = 0
var kills: int = 0
var max_health: float = 100.0
var health: float = 100.0

var base_move_speed: float = 6.0
var base_jump_velocity: float = 8.0

var double_jump_unlocked: bool = false
var triple_jump_unlocked: bool = false
var dash_unlocked: bool = false

# Stacking upgrade counters (see UpgradeDB for caps/effects).
var upgrade_counts: Dictionary = {
	"speed": 0,
	"jump_height": 0,
	"air_control": 0,
	"dash_cooldown": 0,
	"dash_charge": 0,
	"max_health": 0,
	"regen": 0,
	"throw_power": 0,
	"fire_rate": 0,
}

# id -> tier (1..3). Player always starts with the classic snowball.
var unlocked_weapons: Dictionary = {"classic": 1}
var current_weapon: String = "classic"

var _regen_accum: float = 0.0

func _ready() -> void:
	_setup_input_map()
	reset_run()

func reset_run() -> void:
	state = State.MENU
	wave = 0
	score = 0
	kills = 0
	upgrade_counts = {
		"speed": 0, "jump_height": 0, "air_control": 0,
		"dash_cooldown": 0, "dash_charge": 0,
		"max_health": 0, "regen": 0, "throw_power": 0, "fire_rate": 0,
	}
	double_jump_unlocked = false
	triple_jump_unlocked = false
	dash_unlocked = false
	unlocked_weapons = {"classic": 1}
	current_weapon = "classic"
	max_health = 100.0
	health = max_health
	_regen_accum = 0.0
	emit_signal("health_changed", health, max_health)
	emit_signal("score_changed", score)
	emit_signal("kills_changed", kills)
	emit_signal("wave_changed", wave)
	emit_signal("weapon_changed", current_weapon, unlocked_weapons[current_weapon])

func set_state(new_state: int) -> void:
	if state == new_state:
		return
	state = new_state
	emit_signal("state_changed", state)

func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	var regen: float = upgrade_counts.get("regen", 0)
	if regen > 0.0 and health > 0.0 and health < max_health:
		_regen_accum += regen * delta
		if _regen_accum >= 1.0:
			var whole: float = floor(_regen_accum)
			_regen_accum -= whole
			heal(whole)

func add_score(amount: int) -> void:
	score += amount
	emit_signal("score_changed", score)

func add_kill() -> void:
	kills += 1
	emit_signal("kills_changed", kills)

func take_damage(amount: float) -> void:
	if state != State.PLAYING:
		return
	health = max(0.0, health - amount)
	emit_signal("health_changed", health, max_health)
	if health <= 0.0:
		emit_signal("player_died")

func heal(amount: float) -> void:
	health = min(max_health, health + amount)
	emit_signal("health_changed", health, max_health)

func advance_wave() -> void:
	wave += 1
	emit_signal("wave_changed", wave)

# --- Derived stats -----------------------------------------------------
func get_move_speed() -> float:
	return base_move_speed + upgrade_counts.get("speed", 0) * 1.2

func get_jump_velocity() -> float:
	return base_jump_velocity + upgrade_counts.get("jump_height", 0) * 1.5

func get_max_jumps() -> int:
	var n := 1
	if double_jump_unlocked:
		n = 2
	if triple_jump_unlocked:
		n = 3
	return n

func get_air_control_mult() -> float:
	return 1.0 + upgrade_counts.get("air_control", 0) * 0.35

func get_dash_cooldown() -> float:
	return max(0.8, 2.6 - upgrade_counts.get("dash_cooldown", 0) * 0.6)

func get_dash_charges() -> int:
	return 1 + upgrade_counts.get("dash_charge", 0)

func get_throw_power_mult() -> float:
	return 1.0 + upgrade_counts.get("throw_power", 0) * 0.10

func get_fire_rate_mult() -> float:
	return pow(0.9, upgrade_counts.get("fire_rate", 0))

# --- Weapons -------------------------------------------------------------
func unlock_weapon(id: String) -> void:
	if not unlocked_weapons.has(id):
		unlocked_weapons[id] = 1

func upgrade_weapon(id: String) -> void:
	if unlocked_weapons.has(id):
		unlocked_weapons[id] = min(3, unlocked_weapons[id] + 1)

func set_current_weapon(id: String) -> void:
	if unlocked_weapons.has(id) and current_weapon != id:
		current_weapon = id
		emit_signal("weapon_changed", current_weapon, unlocked_weapons[current_weapon])

func cycle_weapon(direction: int) -> void:
	var ids: Array = unlocked_weapons.keys()
	ids.sort()
	if ids.is_empty():
		return
	var idx: int = ids.find(current_weapon)
	if idx == -1:
		idx = 0
	idx = wrapi(idx + direction, 0, ids.size())
	set_current_weapon(ids[idx])

func apply_upgrades_changed() -> void:
	emit_signal("upgrades_applied")

# --- Input map (built here so no hand-edited resource blobs live in
# project.godot; keys are bound by symbolic KEY_* constants). ---------------
func _setup_input_map() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_back", KEY_S)
	_bind_key("move_left", KEY_A)
	_bind_key("move_right", KEY_D)
	_bind_key("jump", KEY_SPACE)
	_bind_key("sprint", KEY_SHIFT)
	_bind_key("dash", KEY_Q)
	_bind_key("pause", KEY_ESCAPE)
	_bind_key("weapon_1", KEY_1)
	_bind_key("weapon_2", KEY_2)
	_bind_key("weapon_3", KEY_3)
	_bind_key("weapon_4", KEY_4)
	_bind_key("weapon_5", KEY_5)
	_bind_key("weapon_6", KEY_6)
	_bind_mouse("throw", MOUSE_BUTTON_LEFT)
	_bind_mouse("weapon_next", MOUSE_BUTTON_WHEEL_DOWN)
	_bind_mouse("weapon_prev", MOUSE_BUTTON_WHEEL_UP)

func _bind_key(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _bind_mouse(action: String, button_index: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button_index
	InputMap.action_add_event(action, ev)
