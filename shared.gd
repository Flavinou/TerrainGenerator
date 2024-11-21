extends Node

const SCALE: float = 5

enum NormalizeMode { Local = 0, Global = 1 }

@onready var viewer: Node = get_node("/root/TerrainGenerator/Viewer")

var viewer_position: Vector2
var last_visible_terrain_chunks: Array[TerrainChunk] = []

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	viewer_position = Vector2(viewer.position.x, viewer.position.z) / SCALE
