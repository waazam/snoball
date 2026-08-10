extends CanvasLayer

@onready var health_label: Label = $Root/StarIcon/HealthLabel
@onready var ball_icon: Control = $Root/BallIcon
@onready var ball_tier_label: Label = $Root/BallIcon/TierLabel
@onready var weapon_name_label: Label = $Root/WeaponNameLabel
@onready var wave_label: Label = $Root/WaveLabel
@onready var kills_label: Label = $Root/KillsLabel
@onready var pause_overlay: Control = $Root/PauseOverlay
@onready var toast_label: Label = $Root/ToastLabel

var _toast_timer: float = 0.0

func _ready() -> void:
	Game.health_changed.connect(_on_health_changed)
	Game.wave_changed.connect(_on_wave_changed)
	Game.kills_changed.connect(_on_kills_changed)
	Game.weapon_changed.connect(_on_weapon_changed)
	Game.upgrade_picked.connect(_on_upgrade_picked)
	_on_health_changed(Game.health, Game.max_health)
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

func _on_wave_changed(wave: int) -> void:
	wave_label.text = "Wave %d" % wave

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
