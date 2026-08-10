extends Node
## Data-only singleton describing every snowball type and its 3 upgrade tiers.
## Snowball.gd reads get_stats(id, tier) to configure a thrown projectile.

# Base (tier-independent) fields, overridden per tier below.
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

const TYPES := {
	"classic": {
		"name": "Classic Snowball",
		"color": Color(0.95, 0.97, 1.0),
		"desc": "A reliable, well-rounded pack of snow.",
		"tiers": [
			{"tier_name": "Classic Snowball", "damage": 12.0, "cooldown": 0.45, "speed": 30.0},
			{"tier_name": "Packed Snowball", "damage": 16.0, "cooldown": 0.40, "speed": 32.0},
			{"tier_name": "Ice Boulder Snowball", "damage": 24.0, "cooldown": 0.38, "speed": 34.0, "splash_radius": 2.5},
		],
	},
	"shard": {
		"name": "Ice Shard",
		"color": Color(0.55, 0.85, 1.0),
		"desc": "A sharpened sliver of ice that pierces through foes.",
		"tiers": [
			{"tier_name": "Ice Shard", "damage": 7.0, "cooldown": 0.35, "speed": 42.0, "pierce": 2, "radius": 0.15},
			{"tier_name": "Frost Shard", "damage": 9.0, "cooldown": 0.32, "speed": 46.0, "pierce": 4, "radius": 0.15},
			{"tier_name": "Glacier Spike", "damage": 12.0, "cooldown": 0.30, "speed": 50.0, "pierce": 6, "radius": 0.17, "freeze_duration": 1.5, "freeze_factor": 0.5},
		],
	},
	"cluster": {
		"name": "Cluster Bomb",
		"color": Color(1.0, 0.85, 0.4),
		"desc": "Bursts into smaller snowballs on impact.",
		"tiers": [
			{"tier_name": "Cluster Bomb", "damage": 6.0, "cooldown": 0.7, "speed": 24.0, "radius": 0.3, "cluster_count": 5},
			{"tier_name": "Shrapnel Bomb", "damage": 7.0, "cooldown": 0.65, "speed": 26.0, "radius": 0.3, "cluster_count": 7},
			{"tier_name": "Avalanche Bomb", "damage": 8.0, "cooldown": 0.6, "speed": 28.0, "radius": 0.32, "cluster_count": 9, "splash_radius": 1.2},
		],
	},
	"homing": {
		"name": "Frost Seeker",
		"color": Color(0.7, 0.6, 1.0),
		"desc": "Curves through the air to chase the nearest enemy.",
		"tiers": [
			{"tier_name": "Frost Seeker", "damage": 9.0, "cooldown": 0.55, "speed": 22.0, "homing": 3.0, "gravity_scale": 0.15},
			{"tier_name": "Blizzard Seeker", "damage": 12.0, "cooldown": 0.5, "speed": 24.0, "homing": 4.5, "gravity_scale": 0.1},
			{"tier_name": "Whiteout Seeker", "damage": 16.0, "cooldown": 0.45, "speed": 26.0, "homing": 6.0, "gravity_scale": 0.05, "pierce": 2},
		],
	},
	"blizzard": {
		"name": "Blizzard Flurry",
		"color": Color(0.8, 0.95, 1.0),
		"desc": "Small, fast, and thrown at a rapid rate.",
		"tiers": [
			{"tier_name": "Blizzard Flurry", "damage": 4.0, "cooldown": 0.14, "speed": 36.0, "radius": 0.14},
			{"tier_name": "Whirlwind Flurry", "damage": 5.0, "cooldown": 0.11, "speed": 38.0, "radius": 0.14},
			{"tier_name": "Hailstorm Flurry", "damage": 6.0, "cooldown": 0.08, "speed": 40.0, "radius": 0.15, "freeze_duration": 0.6, "freeze_factor": 0.7},
		],
	},
	"boulder": {
		"name": "Great Boulder",
		"color": Color(0.55, 0.6, 0.7),
		"desc": "A massive, slow-flying block of packed ice.",
		"tiers": [
			{"tier_name": "Great Boulder", "damage": 40.0, "cooldown": 1.4, "speed": 18.0, "radius": 0.8, "splash_radius": 3.5, "knockback": 8.0},
			{"tier_name": "Glacial Boulder", "damage": 55.0, "cooldown": 1.3, "speed": 19.0, "radius": 0.85, "splash_radius": 4.5, "knockback": 10.0},
			{"tier_name": "Titan Boulder", "damage": 75.0, "cooldown": 1.2, "speed": 20.0, "radius": 0.9, "splash_radius": 6.0, "knockback": 14.0, "freeze_duration": 1.0, "freeze_factor": 0.3},
		],
	},
}

func all_ids() -> Array:
	return TYPES.keys()

func get_display_name(id: String) -> String:
	return TYPES.get(id, {}).get("name", id)

func get_color(id: String) -> Color:
	return TYPES.get(id, {}).get("color", Color.WHITE)

func get_desc(id: String) -> String:
	return TYPES.get(id, {}).get("desc", "")

func get_tier_name(id: String, tier: int) -> String:
	var stats := get_stats(id, tier)
	return stats.get("tier_name", get_display_name(id))

## Returns a merged dictionary of BASE defaults + this type's tier overrides.
func get_stats(id: String, tier: int) -> Dictionary:
	var def: Dictionary = TYPES.get(id, TYPES["classic"])
	var tiers: Array = def["tiers"]
	var idx: int = clampi(tier - 1, 0, tiers.size() - 1)
	var stats: Dictionary = BASE.duplicate()
	for k in tiers[idx]:
		stats[k] = tiers[idx][k]
	return stats
