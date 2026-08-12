extends CanvasLayer

signal upgrade_selected

@onready var cards: Array = [$Root/Card1, $Root/Card2, $Root/Card3]
@onready var subtitle: Label = $Root/Subtitle

var _offers: Array = []

func _ready() -> void:
	visible = false
	for i in cards.size():
		var card: Control = cards[i]
		card.get_node("ClickButton").pressed.connect(_on_card_pressed.bind(i))

func open() -> void:
	subtitle.text = "Wave %d Cleared!" % Game.wave
	_offers = UpgradeDB.get_offers(3)
	for i in cards.size():
		var card: Control = cards[i]
		if i < _offers.size():
			var offer: Dictionary = _offers[i]
			card.visible = true
			# "Bg" is now the card's colored accent strip under the title -
			# the offer's signature color at full strength on a dark panel.
			card.get_node("Bg").color = Color(offer.color, 1.0)
			card.get_node("TitleLabel").text = offer.title
			card.get_node("DescLabel").text = offer.desc
			card.get_node("KeyHint").text = "Press %d" % (i + 1)
		else:
			card.visible = false
	visible = true
	# Visual-only fade-in so the choice moment lands softly.
	var root: Control = $Root
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.22)

func _process(_delta: float) -> void:
	if not visible:
		return
	for i in _offers.size():
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
			_on_card_pressed(i)

func _on_card_pressed(i: int) -> void:
	if i >= _offers.size():
		return
	var offer: Dictionary = _offers[i]
	visible = false
	UpgradeDB.apply(offer)
	emit_signal("upgrade_selected")
