extends Node
## Data-only singleton describing the 9 snowball types. There's no
## unlocking/upgrading here (unlike the old tiered-weapon system this
## replaced) - which one the player currently throws is purely decided by
## the last "present" pickup they collected (see PresentPickup.gd +
## Game.equip_snowball). Snowball.gd reads get_stats(id) to configure a
## thrown projectile's physics and SnowballVisuals.gd/get_shape(id) to
## build its look; "effect" drives what happens to an enemy it hits (see
## Snowball._hit_enemy). "rarity" is the present pickup's drop weight -
## higher rolls more often (see get_random_id).

const TYPES := {
	"standard": {
		"display_name": "Standard Snowball",
		"desc": "A reliable, well-packed snowball. Nothing fancy.",
		"damage": 20.0,
		"color": Color(0.92, 0.94, 0.97),
		"shape": "standard",
		"effect": "none",
		"rarity": 20,
	},
	"perfect_white": {
		"display_name": "Perfect Snowball",
		"desc": "Flawlessly round and pure white. Thrown in total silence.",
		"damage": 20.0,
		"color": Color(1.0, 1.0, 1.0),
		"shape": "perfect_white",
		"effect": "silent",
		"rarity": 12,
	},
	"piss_ball": {
		"display_name": "Yellow Snowball",
		"desc": "Best not to ask. Leaves yellow footprints behind whatever it hits.",
		"damage": 20.0,
		"color": Color(0.82, 0.74, 0.12),
		"shape": "piss_ball",
		"effect": "footprints",
		"effect_color": Color(0.85, 0.72, 0.1),
		"effect_duration": 10.0,
		"rarity": 12,
	},
	"gravel": {
		"display_name": "Gravel Snowball",
		"desc": "Studded with rock. Bursts in a shotgun blast on impact.",
		"damage": 25.0,
		"color": Color(0.55, 0.52, 0.48),
		"shape": "gravel",
		"effect": "shotgun",
		"effect_radius": 3.0,
		"rarity": 10,
	},
	"sap": {
		"display_name": "Tree Sap Snowball",
		"desc": "Sticky sap and pine needles. Slows whatever it hits.",
		"damage": 15.0,
		"color": Color(0.62, 0.78, 0.32),
		"shape": "sap",
		"effect": "slow",
		"effect_duration": 2.5,
		"effect_factor": 0.45,
		"rarity": 12,
	},
	"sticks": {
		"display_name": "Stick Snowball",
		"desc": "Bristling with sharp sticks. Causes bleeding.",
		"damage": 25.0,
		"color": Color(0.85, 0.9, 0.95),
		"shape": "sticks",
		"effect": "bleed",
		"effect_dps": 4.0,
		"effect_duration": 5.0,
		"rarity": 10,
	},
	"ice": {
		"display_name": "Ice Snowball",
		"desc": "Dripping with meltwater. Explodes into a freezing blast.",
		"damage": 50.0,
		"color": Color(0.55, 0.85, 0.98),
		"shape": "ice",
		"effect": "ice_explosion",
		"effect_radius": 3.5,
		"effect_duration": 2.0,
		"effect_factor": 0.2,
		"rarity": 6,
	},
	"nails": {
		"display_name": "Nail Snowball",
		"desc": "Studded with rusty nails. Causes bleeding.",
		"damage": 30.0,
		"color": Color(0.9, 0.92, 0.95),
		"shape": "nails",
		"effect": "bleed",
		"effect_dps": 5.0,
		"effect_duration": 5.0,
		"rarity": 8,
	},
	"death_ball": {
		"display_name": "Death Snowball",
		"desc": "A pulsating void of purple and black. Obliterates on contact.",
		"damage": 9999.0,
		"color": Color(0.28, 0.05, 0.38),
		"shape": "death_ball",
		"effect": "instakill",
		"rarity": 1,
	},
}

# Tier-independent physics defaults, overridden per type's effect in get_stats().
const BASE := {
	"speed": 30.0,
	"gravity_scale": 1.0,
	"radius": 0.22,
	"pierce": 1,
	"splash_radius": 0.0,
	"cluster_count": 0,
	"homing": 0.0,
	"knockback": 2.0,
	"freeze_duration": 0.0,
	"freeze_factor": 1.0,
}

func all_ids() -> Array:
	return TYPES.keys()

func get_data(id: String) -> Dictionary:
	return TYPES.get(id, TYPES["standard"])

func get_display_name(id: String) -> String:
	return get_data(id).get("display_name", id)

func get_desc(id: String) -> String:
	return get_data(id).get("desc", "")

func get_color(id: String) -> Color:
	return get_data(id).get("color", Color.WHITE)

func get_shape(id: String) -> String:
	return get_data(id).get("shape", "standard")

func get_effect(id: String) -> String:
	return get_data(id).get("effect", "none")

## Merged BASE physics defaults + this type's damage and (where the effect
## maps onto an existing projectile mechanic - splash/freeze) its params.
## Effects with no physics equivalent (footprints, bleed, instakill,
## silent) are read straight off get_data() by Snowball.gd instead.
func get_stats(id: String) -> Dictionary:
	var stats: Dictionary = BASE.duplicate()
	var data: Dictionary = get_data(id)
	stats["damage"] = data.get("damage", 10.0)
	match data.get("effect", "none"):
		"shotgun":
			stats["splash_radius"] = data.get("effect_radius", 3.0)
		"slow":
			stats["freeze_duration"] = data.get("effect_duration", 2.5)
			stats["freeze_factor"] = data.get("effect_factor", 0.45)
		"ice_explosion":
			stats["splash_radius"] = data.get("effect_radius", 3.5)
			stats["freeze_duration"] = data.get("effect_duration", 2.0)
			stats["freeze_factor"] = data.get("effect_factor", 0.2)
	return stats

## Weighted random pick for present pickups - "rarity" is the weight, so
## the death ball (rarity 1 against everything else's 6-20) is by far the
## least likely to come up.
func get_random_id() -> String:
	var total: float = 0.0
	for id in TYPES:
		total += float(TYPES[id].get("rarity", 1))
	var roll: float = randf() * total
	var accum: float = 0.0
	for id in TYPES:
		accum += float(TYPES[id].get("rarity", 1))
		if roll < accum:
			return id
	return "standard"
