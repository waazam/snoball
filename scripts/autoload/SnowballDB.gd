extends Node
## Data-only singleton describing the 9 snowball types. Which one the player
## currently throws is decided by which they've equipped from the main
## menu's Snowballs submenu (see Progress.gd/SnowballMenu.gd) - permanent
## until they equip a different one there. Snowball.gd reads get_stats(id)
## to configure a thrown projectile's physics and SnowballVisuals.gd/
## get_shape(id) to build its look; "effect" drives what happens to an
## enemy it hits (see Snowball._hit_enemy). "order"/"unlock_wave" describe
## permanent progression - see get_unlockable_ids_ordered()/get_unlock_wave()
## and Progress.gd, which tracks the player's all-time best cleared wave and
## compares it against unlock_wave to decide what's unlocked.

const TYPES := {
	"sticks": {
		"display_name": "Stick Snowball",
		"desc": "Bristling with sharp sticks. Causes bleeding.",
		"damage": 25.0,
		"color": Color("#EAF2FB"),
		"shape": "sticks",
		"effect": "bleed",
		"effect_dps": 4.0,
		"effect_duration": 5.0,
		"order": 5,
		"unlock_wave": 12,
	},
	"death_ball": {
		"display_name": "Death Snowball",
		"desc": "A pulsating void of purple and black. Obliterates on contact.",
		"damage": 9999.0,
		"color": Color("#47106B"),
		"shape": "death_ball",
		"effect": "instakill",
		"order": 9,
		"unlock_wave": 25,
	},
	"piss_ball": {
		"display_name": "Yellow Snowball",
		"desc": "Best not to ask. Leaves yellow footprints behind whatever it hits.",
		"damage": 20.0,
		"color": Color("#D9B81C"),
		"shape": "piss_ball",
		"effect": "footprints",
		"effect_color": Color("#D9B81C"),
		"effect_duration": 10.0,
		"order": 3,
		"unlock_wave": 6,
	},
	"ice": {
		"display_name": "Ice Snowball",
		"desc": "Dripping with meltwater. Explodes into a freezing blast.",
		"damage": 50.0,
		"color": Color("#A8E4FF"),
		"shape": "ice",
		"effect": "ice_explosion",
		"effect_radius": 3.5,
		"effect_duration": 2.0,
		"effect_factor": 0.2,
		"order": 8,
		"unlock_wave": 21,
	},
	"standard": {
		"display_name": "Standard Snowball",
		"desc": "A reliable, well-packed snowball. Nothing fancy.",
		"damage": 20.0,
		"color": Color("#EAF2FB"),
		"shape": "standard",
		"effect": "none",
		"order": 1,
		"unlock_wave": 0,
	},
	"nails": {
		"display_name": "Nail Snowball",
		"desc": "Studded with rusty nails. Causes bleeding.",
		"damage": 30.0,
		"color": Color("#EAF2FB"),
		"shape": "nails",
		"effect": "bleed",
		"effect_dps": 5.0,
		"effect_duration": 5.0,
		"order": 6,
		"unlock_wave": 15,
	},
	"sap": {
		"display_name": "Tree Sap Snowball",
		"desc": "Sticky sap and pine needles. Slows whatever it hits.",
		"damage": 15.0,
		"color": Color("#7FA332"),
		"shape": "sap",
		"effect": "slow",
		"effect_duration": 2.5,
		"effect_factor": 0.45,
		"order": 4,
		"unlock_wave": 9,
	},
	"perfect_white": {
		"display_name": "Perfect Snowball",
		"desc": "Flawlessly round and pure white. Thrown in total silence.",
		"damage": 20.0,
		"color": Color("#FFFFFF"),
		"shape": "perfect_white",
		"effect": "silent",
		"order": 2,
		"unlock_wave": 3,
	},
	"gravel": {
		"display_name": "Gravel Snowball",
		"desc": "Studded with rock. Bursts in a shotgun blast on impact.",
		"damage": 25.0,
		"color": Color("#8A8378"),
		"shape": "gravel",
		"effect": "shotgun",
		"effect_radius": 3.0,
		"order": 7,
		"unlock_wave": 18,
	},
	# Not one of the 9 unlockable/equippable types (no order/unlock_wave -
	# excluded from get_unlockable_ids_ordered()): only obtainable by
	# defeating the wave-15 Yeti boss and collecting his dropped
	# SwordPickup, see EnemyYeti.gd/SwordPickup.gd. Temporary for that run
	# only, via Game.equip_snowball directly (not Progress.equip).
	"yeti_sword": {
		"display_name": "Yeti's Christmas Tree Sword",
		"desc": "A massive blade shaped like a decorated tree, strung with lights. Causes heavy bleeding.",
		"damage": 60.0,
		"color": Color("#1C3D24"),
		"shape": "yeti_sword",
		"effect": "bleed",
		"effect_dps": 10.0,
		"effect_duration": 6.0,
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

## The 9 menu-unlockable/equippable types (excludes "yeti_sword", which has
## no "order" key), sorted by unlock progression - see Progress.gd.
func get_unlockable_ids_ordered() -> Array:
	var ids: Array = []
	for id in TYPES:
		if TYPES[id].has("order"):
			ids.append(id)
	ids.sort_custom(func(a, b): return TYPES[a]["order"] < TYPES[b]["order"])
	return ids

## Wave that must be cleared (see Progress.report_wave_cleared) to unlock
## this type. 0 for the standard-issue starter ball.
func get_unlock_wave(id: String) -> int:
	return get_data(id).get("unlock_wave", 0)
