extends CanvasLayer

@onready var heart_icon: Control = $Root/HeartIcon
@onready var health_label: Label = $Root/HeartIcon/HealthLabel
@onready var shield_icon: Control = $Root/ShieldIcon
@onready var armor_label: Label = $Root/ShieldIcon/ArmorLabel
@onready var ball_icon: Control = $Root/BallIcon
@onready var ball_tier_label: Label = $Root/BallIcon/TierLabel
@onready var weapon_name_label: Label = $Root/WeaponNameLabel
@onready var wave_label: Label = $Root/WaveLabel
@onready var kills_label: Label = $Root/KillsLabel
@onready var pause_overlay: Control = $Root/PauseOverlay
@onready var toast_label: Label = $Root/ToastLabel

const ARMOR_COLOR := Color(0.55, 0.6, 0.68)

var _toast_timer: float = 0.0

func _ready() -> void:
	Game.health_changed.connect(_on_health_changed)
	Game.armor_changed.connect(_on_armor_changed)
	Game.wave_changed.connect(_on_wave_changed)
	Game.kills_changed.connect(_on_kills_changed)
	Game.weapon_changed.connect(_on_weapon_changed)
	Game.upgrade_picked.connect(_on_upgrade_picked)
	_on_health_changed(Game.health, Game.max_health)
	_on_armor_changed(Game.armor, Game.max_armor)
	_on_wave_changed(Game.wave)
	_on_kills_changed(Game.kills)
	_on_weapon_changed(Game.current_weapon, Game.unlocked_weapons.get(Game.current_weapon, 1))
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

func _on_kills_changed(kills: int) -> void:
	kills_label.text = "Kills: %d" % kills

func _on_weapon_changed(id: String, tier: int) -> void:
	ball_icon.fill_color = SnowballDB.get_color(id)
	ball_tier_label.text = "T%d" % tier
	weapon_name_label.text = SnowballDB.get_tier_name(id, tier)

func _on_upgrade_picked(title: String) -> void:
	toast_label.text = "Acquired: %s" % title
	toast_label.visible = true
	_toast_timer = 2.5

func set_paused(paused: bool) -> void:
	pause_overlay.visible = paused
