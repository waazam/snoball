extends Node
## Data-only singleton describing pickup-able hats. Each hat is a one-time
## consumable found on the ground (see HatPickup.gd): touching it re-equips
## the player's hat to that color/shape and grants its stat bonus, reusing
## the same derived-stat plumbing as the between-wave upgrade cards.

const TYPES := {
	"knight_helm": {
		"display_name": "Knight's Helm",
		"desc": "+25 armor, fully charged",
		"color": Color("#9AA4B5"),
		"shape": "knight_helmet",
		"kind": "armor",
		"amount": 25.0,
	},
	"berserker_horns": {
		"display_name": "Berserker Horns",
		"desc": "Snowballs hit harder and fly faster",
		"color": Color("#B52A24"),
		"shape": "horns",
		"kind": "throw_power",
		"amount": 1,
	},
	"swift_cap": {
		"display_name": "Swift Cap",
		"desc": "Move a little faster",
		"color": Color("#2E7D46"),
		"shape": "cat_ears",
		"kind": "speed",
		"amount": 1,
	},
	"frost_crown": {
		"display_name": "Frost Wizard Hat",
		"desc": "+20 max health, fully healed",
		"color": Color("#5A8FD9"),
		"shape": "wizard_hat",
		"kind": "max_health",
		"amount": 20.0,
	},
	"lucky_top_hat": {
		"display_name": "Lucky Top Hat",
		"desc": "+40 score and a bit of healing",
		"color": Color("#26221F"),
		"shape": "top_hat",
		"kind": "treasure",
		"amount": 40,
	},
}

func all_ids() -> Array:
	return TYPES.keys()

func get_data(id: String) -> Dictionary:
	return TYPES.get(id, TYPES["knight_helm"])

func get_random_id() -> String:
	var ids: Array = all_ids()
	return ids[randi() % ids.size()]

## Applies the hat's stat bonus to Game and equips it visually (via the
## Game.hat_equipped signal, which Player.gd listens for).
func apply(id: String) -> void:
	var data: Dictionary = get_data(id)
	match data.get("kind", ""):
		"armor":
			Game.add_armor(data.get("amount", 0.0))
		"throw_power", "speed":
			var key: String = data.get("kind", "")
			Game.upgrade_counts[key] = Game.upgrade_counts.get(key, 0) + int(data.get("amount", 1))
			Game.apply_upgrades_changed()
		"max_health":
			Game.max_health += data.get("amount", 0.0)
			Game.heal(data.get("amount", 0.0))
		"treasure":
			Game.add_score(int(data.get("amount", 0)))
			Game.heal(15.0)
	Game.equip_hat(id)
	Game.emit_signal("upgrade_picked", "%s equipped!" % data.get("display_name", id))
