extends Node
## Data-only singleton describing enemy presets. Enemy.gd reads get_stats(id)
## and WaveManager reads get_wave_composition(wave) to decide what to spawn.

const STATS := {
	"grunt": {
		"display_name": "Reindeer",
		"health": 30.0,
		"speed": 3.6,
		"damage": 8.0,
		"attack_range": 1.7,
		"attack_cooldown": 1.0,
		"is_ranged": false,
		"scale": 1.0,
		"color": Color(0.62, 0.42, 0.25),
		"scene_path": "res://scenes/enemies/EnemyReindeer.tscn",
		"score": 10,
	},
	"thrower": {
		"display_name": "Rogue Elf",
		"health": 22.0,
		"speed": 3.1,
		"damage": 6.0,
		"attack_range": 11.0,
		"attack_cooldown": 1.6,
		"is_ranged": true,
		"scale": 0.9,
		"color": Color(0.45, 0.12, 0.5),
		"scene_path": "res://scenes/enemies/EnemyElf.tscn",
		"score": 15,
	},
	"brute": {
		"display_name": "Elder Reindeer",
		"health": 95.0,
		"speed": 2.3,
		"damage": 18.0,
		"attack_range": 2.2,
		"attack_cooldown": 1.3,
		"is_ranged": false,
		"scale": 1.5,
		"color": Color(0.32, 0.22, 0.14),
		"scene_path": "res://scenes/enemies/EnemyReindeer.tscn",
		"score": 30,
	},
}

func get_stats(id: String) -> Dictionary:
	return STATS.get(id, STATS["grunt"]).duplicate()

func get_scene_path(id: String) -> String:
	return STATS.get(id, STATS["grunt"]).get("scene_path", "res://scenes/enemies/EnemyReindeer.tscn")

## Difficulty scaling applied on top of base stats for a given wave number.
func get_scaled_stats(id: String, wave: int) -> Dictionary:
	var s := get_stats(id)
	var w: int = maxi(0, wave - 1)
	s["health"] = s["health"] * (1.0 + w * 0.14)
	s["damage"] = s["damage"] * (1.0 + w * 0.08)
	s["speed"] = s["speed"] * (1.0 + min(w * 0.02, 0.3))
	return s

## Returns an Array[String] of enemy ids to spawn for the given wave.
func get_wave_composition(wave: int) -> Array:
	var comp: Array = []
	var grunts: int = 3 + wave
	for i in grunts:
		comp.append("grunt")
	if wave >= 2:
		var throwers: int = 1 + int(wave / 2)
		for i in throwers:
			comp.append("thrower")
	if wave >= 4:
		var brutes: int = 1 + int((wave - 4) / 3)
		for i in brutes:
			comp.append("brute")
	comp.shuffle()
	return comp
