extends Node3D
## A small string of procedural "Christmas lights" wound in a spiral around
## any cone-shaped mesh (a tapered CylinderMesh, top_radius ~0) - used for
## the reindeer's antlers (EnemyReindeer.tscn) and the arena's tree canopies
## (Arena.tscn). Meant to be parented directly under the cone's own
## MeshInstance3D so that mesh's transform (and any scale, e.g. the tripled
## antlers) carries the whole light string along with it - beam_height/
## beam_base_radius below should match that mesh's own local (un-scaled)
## height/bottom_radius, and bulb_radius/wrap_clearance should be re-tuned
## per use since a light bulb needs a very different absolute size and
## surface clearance on a thin antler spike vs. a whole tree canopy.
##
## Each bulb glows on its own slow, phase-offset sine pulse instead of a
## flat static color or a hard on/off blink, for a gentle "still glowing"
## feel.

@export var beam_height: float = 0.4
@export var beam_base_radius: float = 0.045
@export var bulb_count: int = 4
@export var wraps: float = 1.4
@export var pulse_speed: float = 1.6  # rad/s - slow breathing glow, not a fast twinkle
@export var bulb_radius: float = 0.028
@export var wrap_clearance: float = 1.8  # how far proud of the cone surface bulbs sit, as a multiplier

const COLORS := [
	Color(0.85, 0.1, 0.12),   # red
	Color(0.15, 0.55, 0.2),   # green
	Color(0.9, 0.75, 0.2),    # gold
	Color(0.25, 0.45, 0.85),  # blue
]

var _bulb_mats: Array = []  # [{mat: StandardMaterial3D, phase: float}]
var _time: float = 0.0

func _ready() -> void:
	for i in range(bulb_count):
		_spawn_bulb(i)

func _spawn_bulb(i: int) -> void:
	var t: float = float(i) / float(maxi(bulb_count - 1, 1))
	var y: float = lerpf(-beam_height * 0.5, beam_height * 0.42, t)
	var radius_here: float = beam_base_radius * (1.0 - t) * wrap_clearance + 0.01
	var angle: float = t * TAU * wraps
	var pos := Vector3(cos(angle) * radius_here, y, sin(angle) * radius_here)

	var sphere := SphereMesh.new()
	sphere.radius = bulb_radius
	sphere.height = bulb_radius * 2.0

	var color: Color = COLORS[i % COLORS.size()]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.0

	var bulb := MeshInstance3D.new()
	bulb.mesh = sphere
	bulb.material_override = mat
	bulb.position = pos
	add_child(bulb)

	_bulb_mats.append({"mat": mat, "phase": t * TAU * 0.5})

func _process(delta: float) -> void:
	_time += delta
	for b in _bulb_mats:
		var glow: float = 0.55 + 0.55 * sin(_time * pulse_speed + b["phase"])
		b["mat"].emission_energy_multiplier = maxf(0.05, glow)
