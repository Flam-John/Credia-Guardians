class_name AsciiRoomBuilder
extends Node2D
## Builds a TileMapLayer (with collision) from an ASCII map — used by debug
## rooms so test geometry is versionable text. Real stages (M4+) are authored
## in the editor; this is a testing tool, not the level pipeline.
##
## Legend:  '#' solid top-lit   '@' solid interior   '.' background panel
##          '^' spikes (hazard) '-' one-way platform  ' ' empty

const TILE := 16
const TILESET_TEXTURE := "res://assets/art/tiles/tileset_office.png"

## Atlas coords in tileset_office.png row 0 (see tools/artgen).
const ATLAS := {
	"#": Vector2i(0, 0),
	"@": Vector2i(1, 0),
	".": Vector2i(2, 0),
	"^": Vector2i(3, 0),
	"-": Vector2i(4, 0),
}

@export_multiline var map: String = ""

var tile_layer: TileMapLayer
## Pixel size of the built room, for camera limits.
var room_size: Vector2


func _ready() -> void:
	build()


func build() -> void:
	if tile_layer != null:
		tile_layer.queue_free()
	tile_layer = TileMapLayer.new()
	tile_layer.tile_set = _build_tileset()
	add_child(tile_layer)
	# Trim blank lines only — strip_edges() would also eat leading spaces on
	# the first row and misalign its tiles.
	var lines := map.split("\n")
	while not lines.is_empty() and lines[0].strip_edges().is_empty():
		lines.remove_at(0)
	while not lines.is_empty() and lines[-1].strip_edges().is_empty():
		lines.remove_at(lines.size() - 1)
	var width := 0
	for y in lines.size():
		var line := lines[y]
		width = maxi(width, line.length())
		for x in line.length():
			var ch := line[x]
			if ATLAS.has(ch):
				tile_layer.set_cell(Vector2i(x, y), 0, ATLAS[ch])
	room_size = Vector2(width * TILE, lines.size() * TILE)


func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	# TileSet physics layer 0: solid world; 1: one-way; 2: hazard.
	# NOTE: '^' hazard tiles are inert until the M2 damage pipeline adds a
	# consumer that masks PhysicsLayers.HAZARD (real stages use Area2D hazards
	# per TDD §2.6; tile-body hazards exist only in these debug rooms).
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, PhysicsLayers.WORLD)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(1, PhysicsLayers.PLATFORM_ONEWAY)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(2, PhysicsLayers.HAZARD)

	var src := TileSetAtlasSource.new()
	src.texture = load(TILESET_TEXTURE)
	src.texture_region_size = Vector2i(TILE, TILE)
	# Source must belong to the TileSet BEFORE tiles get collision, otherwise
	# TileData sees zero physics layers.
	ts.add_source(src, 0)
	for ch: String in ATLAS:
		var coords: Vector2i = ATLAS[ch]
		src.create_tile(coords)
		var data := src.get_tile_data(coords, 0)
		match ch:
			"#", "@":
				_add_full_square(data, 0)
			"-":
				_add_platform_strip(data)
			"^":
				_add_full_square(data, 2)
	return ts


func _add_full_square(data: TileData, physics_layer: int) -> void:
	var half := TILE / 2.0
	data.add_collision_polygon(physics_layer)
	data.set_collision_polygon_points(physics_layer, 0, PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	]))


func _add_platform_strip(data: TileData) -> void:
	# Thin strip near the top of the tile, one-way.
	var half := TILE / 2.0
	data.add_collision_polygon(1)
	data.set_collision_polygon_points(1, 0, PackedVector2Array([
		Vector2(-half, -half + 2), Vector2(half, -half + 2),
		Vector2(half, -half + 6), Vector2(-half, -half + 6),
	]))
	data.set_collision_polygon_one_way(1, 0, true)
