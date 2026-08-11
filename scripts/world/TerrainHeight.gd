class_name TerrainHeight
extends RefCounted
## Shared ground-height function for the arena floor's rolling hills -
## queried by both Terrain.gd (which builds the actual visual mesh +
## collision from it) and MapFiller.gd (which needs the same values to
## place its scattered trees/rocks/platforms ON the resulting slopes
## instead of assuming flat ground at y=0, like it used to). A plain
## static function rather than a node reference, so callers don't have to
## worry about _ready() ordering against Terrain - same "static helper,
## no instance needed" approach as HatVisuals.gd.
##
## Height is flat (0) near the map center - covering every hand-placed
## obstacle, platform, and spawn point in Arena.tscn, all of which assume
## flat ground - and right under each of Arena.tscn's hand-placed
## decorated Christmas/bare trees (TREE_POSITIONS below), blending
## smoothly out into real rolling hills everywhere else, and back to flat
## again near the walls so there's no gap/clipping at their base. Nothing
## already hand-authored against flat ground needs to change.

const MAP_HALF_SIZE := 100.0  # matches Arena.tscn's walls (at +-100)
const EDGE_BLEND := 12.0
const CENTER_FLAT_RADIUS := 34.0  # clears every hand-placed obstacle/platform/spawn point (all within ~27 of center)
const CENTER_BLEND := 10.0
const TREE_FLAT_RADIUS := 3.0
const TREE_BLEND := 3.0
const HEIGHT_SCALE := 1.6

# Arena.tscn's hand-placed Tree1-10 (a radius-87.5 ring) + BareTree1-4 (a
# radius-~74.9 ring) - kept in sync with those nodes' positions so the
# ground stays flat directly under each trunk.
const TREE_POSITIONS := [
	Vector2(87.5, 0), Vector2(70.75, 51.5), Vector2(27.0, 83.25), Vector2(-27.0, 83.25),
	Vector2(-70.75, 51.5), Vector2(-87.5, 0), Vector2(-70.75, -51.5), Vector2(-27.0, -83.25),
	Vector2(27.0, -83.25), Vector2(70.75, -51.5),
	Vector2(71.25, 23.175), Vector2(-44.0, 60.75), Vector2(-71.25, -23.175), Vector2(-23.175, -71.25),
]

static func get_height(x: float, z: float) -> float:
	return get_raw_height(x, z) * get_flatten_factor(x, z)

## The rolling-hills shape before flattening is applied - a few overlapping
## low-frequency sine waves at different scales/angles, same "layered
## sine waves read as rolling terrain" trick MountainRange.gd's horizon
## undulation uses, just as a full 2D heightfield instead of a 1D ring.
static func get_raw_height(x: float, z: float) -> float:
	var h: float = 0.0
	h += sin(x * 0.045 + 1.3) * cos(z * 0.05 - 0.7)
	h += sin((x + z) * 0.03 + 4.0) * 0.6
	h += sin(x * 0.09 - z * 0.07) * 0.35
	return h * HEIGHT_SCALE

static func get_flatten_factor(x: float, z: float) -> float:
	var r: float = Vector2(x, z).length()
	var f: float = smoothstep(CENTER_FLAT_RADIUS, CENTER_FLAT_RADIUS + CENTER_BLEND, r)
	for tp in TREE_POSITIONS:
		var d: float = Vector2(x, z).distance_to(tp)
		f = minf(f, smoothstep(TREE_FLAT_RADIUS, TREE_FLAT_RADIUS + TREE_BLEND, d))
	var edge_dist: float = MAP_HALF_SIZE - maxf(absf(x), absf(z))
	f = minf(f, clampf(edge_dist / EDGE_BLEND, 0.0, 1.0))
	return f
