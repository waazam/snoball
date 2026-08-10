extends Node
## Builds the pool of available roguelike upgrade offers based on the current
## Game state, and applies a chosen offer back onto Game.

const CAPS := {
	"speed": 4, "jump_height": 3, "air_control": 2,
	"dash_cooldown": 3, "dash_charge": 1,
	"max_health": 4, "regen": 3, "throw_power": 5, "fire_rate": 5,
}

## Returns up to `n` unique offer dictionaries:
## {id, title, desc, color, category, action, params}
func get_offers(n: int = 3) -> Array:
	var pool: Array = []

	# Weapon unlocks / upgrades.
	for id in SnowballDB.all_ids():
		if not Game.unlocked_weapons.has(id):
			pool.append({
				"id": "unlock_%s" % id,
				"title": "New: %s" % SnowballDB.get_display_name(id),
				"desc": SnowballDB.get_desc(id),
				"color": SnowballDB.get_color(id),
				"category": "weapon",
				"action": "unlock_weapon",
				"params": {"weapon_id": id},
			})
		elif Game.unlocked_weapons[id] < 3:
			var next_tier: int = Game.unlocked_weapons[id] + 1
			var next_name: String = SnowballDB.get_tier_name(id, next_tier)
			pool.append({
				"id": "upgrade_%s" % id,
				"title": "Upgrade: %s" % next_name,
				"desc": "Improves your %s (tier %d/3)." % [SnowballDB.get_display_name(id), next_tier],
				"color": SnowballDB.get_color(id),
				"category": "weapon",
				"action": "upgrade_weapon",
				"params": {"weapon_id": id},
			})

	# Movement.
	if Game.upgrade_counts.speed < CAPS.speed:
		pool.append(_stat_offer("speed", "Swift Boots", "Increases movement speed.", Color(0.4, 0.9, 0.6)))
	if not Game.dash_unlocked:
		pool.append({
			"id": "unlock_dash", "title": "Frost Dash", "desc": "Unlocks a quick burst dash (Q).",
			"color": Color(0.4, 0.9, 0.6), "category": "movement", "action": "unlock_dash", "params": {},
		})
	else:
		if Game.upgrade_counts.dash_cooldown < CAPS.dash_cooldown:
			pool.append(_stat_offer("dash_cooldown", "Chilled Legs", "Reduces dash cooldown.", Color(0.4, 0.9, 0.6)))
		if Game.upgrade_counts.dash_charge < CAPS.dash_charge:
			pool.append(_stat_offer("dash_charge", "Extra Charge", "Grants an additional dash charge.", Color(0.4, 0.9, 0.6)))

	# Jumping.
	if Game.upgrade_counts.jump_height < CAPS.jump_height:
		pool.append(_stat_offer("jump_height", "Spring Legs", "Jump higher.", Color(0.95, 0.75, 0.3)))
	if not Game.double_jump_unlocked:
		pool.append({
			"id": "unlock_double_jump", "title": "Double Jump", "desc": "Unlocks a second jump in mid-air.",
			"color": Color(0.95, 0.75, 0.3), "category": "jump", "action": "unlock_double_jump", "params": {},
		})
	elif not Game.triple_jump_unlocked:
		pool.append({
			"id": "unlock_triple_jump", "title": "Triple Jump", "desc": "Unlocks a third jump in mid-air.",
			"color": Color(0.95, 0.75, 0.3), "category": "jump", "action": "unlock_triple_jump", "params": {},
		})
	if Game.upgrade_counts.air_control < CAPS.air_control:
		pool.append(_stat_offer("air_control", "Featherfall", "Improves control while airborne.", Color(0.95, 0.75, 0.3)))

	# General stats.
	if Game.upgrade_counts.max_health < CAPS.max_health:
		pool.append(_stat_offer("max_health", "Thick Coat", "Increases max health and heals you.", Color(1.0, 0.5, 0.55)))
	if Game.upgrade_counts.regen < CAPS.regen:
		pool.append(_stat_offer("regen", "Warm Blood", "Regenerate health over time.", Color(1.0, 0.5, 0.55)))
	if Game.upgrade_counts.throw_power < CAPS.throw_power:
		pool.append(_stat_offer("throw_power", "Strong Arm", "Increases snowball damage and speed.", Color(0.75, 0.6, 1.0)))
	if Game.upgrade_counts.fire_rate < CAPS.fire_rate:
		pool.append(_stat_offer("fire_rate", "Quick Hands", "Throw snowballs more often.", Color(0.75, 0.6, 1.0)))

	pool.shuffle()
	return pool.slice(0, min(n, pool.size()))

func _stat_offer(key: String, title: String, desc: String, color: Color) -> Dictionary:
	var cur: int = Game.upgrade_counts.get(key, 0)
	var cap: int = CAPS.get(key, 99)
	return {
		"id": "stat_%s" % key,
		"title": "%s (%d/%d)" % [title, cur + 1, cap],
		"desc": desc,
		"color": color,
		"category": "stat",
		"action": "stat",
		"params": {"key": key},
	}

## Applies the chosen offer to Game's persistent state.
func apply(offer: Dictionary) -> void:
	match offer.get("action", ""):
		"unlock_weapon":
			Game.unlock_weapon(offer.params.weapon_id)
			Game.set_current_weapon(offer.params.weapon_id)
		"upgrade_weapon":
			Game.upgrade_weapon(offer.params.weapon_id)
		"unlock_dash":
			Game.dash_unlocked = true
		"unlock_double_jump":
			Game.double_jump_unlocked = true
		"unlock_triple_jump":
			Game.triple_jump_unlocked = true
		"stat":
			var key: String = offer.params.key
			Game.upgrade_counts[key] = Game.upgrade_counts.get(key, 0) + 1
			if key == "max_health":
				Game.max_health = 100.0 + Game.upgrade_counts.max_health * 25.0
				Game.heal(25.0)
	Game.apply_upgrades_changed()
	Game.emit_signal("upgrade_picked", offer.get("title", ""))
