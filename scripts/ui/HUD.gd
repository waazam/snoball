extends CanvasLayer

@onready var heart_icon: Control = $Root/HeartIcon
@onready var health_label: Label = $Root/HeartIcon/HealthLabel
@onready var shield_icon: Control = $Root/ShieldIcon
@onready var armor_label: Label = $Root/ShieldIcon/ArmorLabel
@onready var ball_icon: Control = $Root/BallIcon
@onready var weapon_name_label: Label = $Root/WeaponNameLabel
@onready var wave_label: Label = $Root/WaveLabel
@onready var kills_label: Label = $Root/KillsLabel
@onready var pause_overlay: Control = $Root/PauseOverlay
@onready var toast_label: Label = $Root/ToastLabel
@onready var stats_list: VBoxContainer = $Root/StatsPanel/StatsList
@onready var xp_fill: ColorRect = $Root/XPBar/Fill
@onready var xp_level_label: Label = $Root/XPBar/LevelLabel
@onready var coins_fill: ColorRect = $Root/CoinsBar/Fill
@onready var coins_label: Label = $Root/CoinsBar/CoinsLabel

const ARMOR_COLOR := Color(0.55, 0.6, 0.68)
const STAT_FONT_SIZE := 15

var _toast_timer: float = 0.0

func _ready() -> void:
	Game.health_changed.connect(_on_health_changed)
	Game.armor_changed.connect(_on_armor_changed)
	Game.wave_changed.connect(_on_wave_changed)
	Game.kills_changed.connect(_on_kills_changed)
	Game.snowball_type_changed.connect(_on_snowball_type_changed)
	Game.upgrade_picked.connect(_on_upgrade_picked)
	# Both upgrade cards (Game.upgrades_applied) and hat pickups (which don't
	# always also fire upgrades_applied - see HatDB.apply) need to refresh
	# the stats panel, since either can grant a stat boost.
	Game.upgrades_applied.connect(_refresh_stats)
	Game.hat_equipped.connect(func(_id: String) -> void: _refresh_stats())
	Game.coins_changed.connect(_on_coins_changed)
	_on_health_changed(Game.health, Game.max_health)
	_on_armor_changed(Game.armor, Game.max_armor)
	_on_wave_changed(Game.wave)
	_on_kills_changed(Game.kills)
	_on_snowball_type_changed(Game.current_snowball_type)
	_on_coins_changed(Game.coins_collected)
	_update_xp_bar()
	_refresh_stats()
	pause_overlay.visible = false
	toast_label.visible = false

func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			toast_label.visible = false

func _on_health_changed(current: float, max_health: float) -> void:
	health_label.text = "%d/%d" % [int(current), int(max_health)]
	heart_icon.set_fill_ratio(current / max_health if max_health > 0.0 else 0.0)

func _on_armor_changed(current: float, max_armor: float) -> void:
	if max_armor <= 0.0:
		shield_icon.fill_color = Color(ARMOR_COLOR, 0.25)
		armor_label.text = ""
	else:
		shield_icon.fill_color = ARMOR_COLOR
		armor_label.text = "%d/%d" % [int(current), int(max_armor)]

func _on_wave_changed(wave: int) -> void:
	wave_label.text = "WAVE %d" % wave
	# Also catches run resets (Game.reset_run always emits wave_changed(0)),
	# which is the one place stacked stats/hat need to be cleared back out.
	_refresh_stats()

func _on_kills_changed(kills: int) -> void:
	kills_label.text = "Kills: %d" % kills
	_update_xp_bar()

func _on_snowball_type_changed(id: String) -> void:
	ball_icon.fill_color = SnowballDB.get_color(id)
	weapon_name_label.text = SnowballDB.get_display_name(id)

## Kill-driven "level" - purely cosmetic (see Game.get_level/
## get_level_progress), doesn't touch any stats. Every EXP_PER_LEVEL kills
## fills the bar and bumps the level shown - also mirrored above the
## player's own head, see Player.gd's level label.
func _update_xp_bar() -> void:
	xp_fill.anchor_right = Game.get_level_progress()
	xp_level_label.text = "LV %d" % Game.get_level()

## Just a running total + progress toward the next proj_count upgrade
## (every COINS_PER_PROJECTILE coins, see Game.add_coin()) - not tied to
## the kill-driven level/XP bar above.
func _on_coins_changed(coins_collected: int) -> void:
	var progress: int = coins_collected % Game.COINS_PER_PROJECTILE
	coins_fill.anchor_right = float(progress) / float(Game.COINS_PER_PROJECTILE)
	coins_label.text = "Coins: %d" % coins_collected

func _on_upgrade_picked(title: String) -> void:
	toast_label.text = "Acquired: %s" % title
	toast_label.visible = true
	_toast_timer = 2.5

func set_paused(paused: bool) -> void:
	pause_overlay.visible = paused
	# The game has no separate SFX/music buses - the background track (see
	# Music.gd) plays on Master like everything else, so muting that one bus
	# silences it while paused without touching the AudioStreamPlayer directly.
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), paused)

## Rebuilds the "active power-ups" list from every stacking upgrade counter,
## permanent movement unlocks, and the currently equipped hat, so any boost
## gained from upgrade cards OR hat pickups shows up here.
func _refresh_stats() -> void:
	for c in stats_list.get_children():
		c.queue_free()
	var uc: Dictionary = Game.upgrade_counts
	var lines: Array = []
	if uc.get("speed", 0) > 0:
		lines.append("Move Speed: %.1f" % Game.get_move_speed())
	if uc.get("jump_height", 0) > 0:
		lines.append("Jump Power: %.1f" % Game.get_jump_velocity())
	if uc.get("air_control", 0) > 0:
		lines.append("Air Control: +%d%%" % int(round((Game.get_air_control_mult() - 1.0) * 100.0)))
	if Game.dash_unlocked:
		var charges: int = Game.get_dash_charges()
		lines.append("Dash: %d charge%s, %.1fs CD" % [charges, "" if charges == 1 else "s", Game.get_dash_cooldown()])
	if Game.triple_jump_unlocked:
		lines.append("Jumps: Triple")
	elif Game.double_jump_unlocked:
		lines.append("Jumps: Double")
	if Game.max_health > 100.0:
		lines.append("Max Health: %d" % int(Game.max_health))
	if uc.get("regen", 0) > 0:
		lines.append("Regen: +%d/s" % int(uc.get("regen", 0)))
	if uc.get("throw_power", 0) > 0:
		lines.append("Throw Power: +%d%%" % int(round((Game.get_throw_power_mult() - 1.0) * 100.0)))
	if uc.get("proj_speed", 0) > 0:
		lines.append("Proj Speed: +%d%%" % int(round((Game.get_projectile_speed_mult() - 1.0) * 100.0)))
	if uc.get("proj_count", 0) > 0:
		lines.append("Snowballs/Throw: %d" % Game.get_projectile_count())
	if Game.equipped_hat != "":
		var hat_data: Dictionary = HatDB.get_data(Game.equipped_hat)
		lines.append("Hat: %s" % hat_data.get("display_name", Game.equipped_hat))
	if lines.is_empty():
		lines.append("No power-ups yet")
	for line in lines:
		_add_stat_label(line)

func _add_stat_label(txt: String) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.add_theme_font_size_override("font_size", STAT_FONT_SIZE)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 4)
	stats_list.add_child(lbl)
