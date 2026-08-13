extends Control
## Main menu submenu for permanently equipping one of SnowballDB's 9
## unlockable types (see Progress.gd) - a full-screen overlay added as a
## sibling of MainMenu's Root so it fully covers the main menu while open;
## Back just hides it again, no visibility bookkeeping needed on Root.
## Rows (SnowballRow.tscn) are built once in _ready() and refreshed in
## place on open()/every equip, rather than re-instantiated each time.

const ROW_SCENE: PackedScene = preload("res://scenes/ui/SnowballRow.tscn")

@onready var equipped_label: Label = $Root/EquippedLabel
@onready var list: VBoxContainer = $Root/ScrollContainer/List
@onready var back_button: Button = $Root/BackButton

var _rows: Dictionary = {}  # id (String) -> SnowballRow instance

func _ready() -> void:
	visible = false
	back_button.pressed.connect(func(): visible = false)
	for id in SnowballDB.get_unlockable_ids_ordered():
		var row: Control = ROW_SCENE.instantiate()
		list.add_child(row)
		row.equip_requested.connect(_on_equip_requested)
		_rows[id] = row

func open() -> void:
	_refresh()
	visible = true

func _refresh() -> void:
	for id in _rows:
		_rows[id].setup(id, Progress.is_unlocked(id), id == Progress.equipped_snowball)
	equipped_label.text = "Equipped: %s" % SnowballDB.get_display_name(Progress.equipped_snowball)

func _on_equip_requested(id: String) -> void:
	if Progress.equip(id):
		_refresh()
