extends Control
## One row in SnowballMenu.gd's list - a color swatch (CircleIcon, same
## component HUD.gd uses for the current-ball icon), name/desc, and either
## an "Equip"/"Equipped" button or a "Unlock at Wave N" status label
## depending on Progress.is_unlocked(id). Populated by setup(), not by
## reading Progress/SnowballDB itself, so SnowballMenu.gd stays the single
## place that decides what's shown.

signal equip_requested(id: String)

const LOCKED_COLOR := Color(0.32, 0.32, 0.36)
const LOCKED_BG := Color(0.12, 0.12, 0.14, 0.55)
const EQUIPPED_TINT := Color(1.0, 0.85, 0.3)
const STATUS_DIM := Color(0.75, 0.75, 0.8)

@onready var bg: ColorRect = $Bg
@onready var icon: Control = $Icon
@onready var name_label: Label = $NameLabel
@onready var desc_label: Label = $DescLabel
@onready var status_label: Label = $StatusLabel
@onready var equip_button: Button = $EquipButton

var _id: String = ""

func _ready() -> void:
	equip_button.pressed.connect(func(): emit_signal("equip_requested", _id))

func setup(id: String, unlocked: bool, equipped: bool) -> void:
	_id = id
	var ball_color: Color = SnowballDB.get_color(id)
	name_label.text = SnowballDB.get_display_name(id)
	desc_label.text = SnowballDB.get_desc(id)
	icon.fill_color = ball_color if unlocked else LOCKED_COLOR
	bg.color = Color(ball_color, 0.22) if unlocked else LOCKED_BG

	equip_button.visible = unlocked and not equipped
	if equipped:
		status_label.text = "Equipped"
		status_label.modulate = EQUIPPED_TINT
	elif unlocked:
		status_label.text = ""
	else:
		status_label.text = "Unlock at Wave %d" % SnowballDB.get_unlock_wave(id)
		status_label.modulate = STATUS_DIM
