extends Node
## Data-only singleton for the cookie/candy-cane pickups. Cookies heal you,
## candy canes grant projectile speed (stacking, diminishing returns - same
## spirit as the upgrade-card stats). Neither touches throw cadence.

const COOKIE_HEAL := 20.0

const TYPES := {
	"cookie": {
		"display_name": "Cookie",
		"desc": "Restores health",
		"kind": "heal",
		"visual": "cookie",
	},
	"candy_cane": {
		"display_name": "Candy Cane",
		"desc": "Snowballs fly faster",
		"kind": "proj_speed",
		"visual": "candy_cane",
	},
}

func all_ids() -> Array:
	return TYPES.keys()

func get_data(id: String) -> Dictionary:
	return TYPES.get(id, TYPES["cookie"])

func get_random_id() -> String:
	var ids: Array = all_ids()
	return ids[randi() % ids.size()]

func apply(id: String) -> void:
	var data: Dictionary = get_data(id)
	var kind: String = data.get("kind", "heal")
	if kind == "heal":
		Game.heal(COOKIE_HEAL)
	else:
		Game.upgrade_counts[kind] = Game.upgrade_counts.get(kind, 0) + 1
		Game.apply_upgrades_changed()
	Game.emit_signal("upgrade_picked", "%s!" % data.get("display_name", id))
