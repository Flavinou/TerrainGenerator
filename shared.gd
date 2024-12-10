extends Node

const FLOAT_MAX: float = 1.79769e308
const FLOAT_MIN: float = -1.79769e308
const INT_MAX: float = 9223372036854775807
const INT_MIN: float = -9223372036854775808

enum NormalizeMode { Local = 0, Global = 1 }

@onready var terrain_generator: TerrainGenerator = get_node("/root/TerrainGenerator")
@onready var viewer: Node = get_node("/root/TerrainGenerator/Player")

var viewer_position: Vector2
var last_visible_terrain_chunks: Array[TerrainChunk] = []

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	viewer_position = Vector2(viewer.position.x, viewer.position.z) / terrain_generator.terrain_data.uniform_scale
