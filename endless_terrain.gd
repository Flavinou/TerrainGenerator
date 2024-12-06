extends Node3D

class_name EndlessTerrain

@onready var terrain_generator = get_node("/root/TerrainGenerator")

@export var material: Material
@export var detail_levels: Array[LODInfo] = []

const VIEWER_MOVE_THRESHOLD_CHUNK_UPDATE: float = 25
const SQR_VIEWER_MOVE_THRESHOLD_CHUNK_UPDATE: float = VIEWER_MOVE_THRESHOLD_CHUNK_UPDATE * VIEWER_MOVE_THRESHOLD_CHUNK_UPDATE

var max_view_distance: float = 450
var viewer_position: Vector2
var old_viewer_position: Vector2

var chunk_size: int
var chunks_visible_in_view_dst: int

var terrain_chunk_dictionary: Dictionary = {}

func _ready():
	max_view_distance = detail_levels[-1].visible_distance_threshold
	chunk_size = terrain_generator.map_chunk_size - 1
	chunks_visible_in_view_dst = roundi(max_view_distance / chunk_size)
	
	update_visible_chunks()
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	viewer_position = Shared.viewer_position
	
	if (old_viewer_position - viewer_position).length_squared() > SQR_VIEWER_MOVE_THRESHOLD_CHUNK_UPDATE:
		old_viewer_position = viewer_position
		update_visible_chunks()


func update_visible_chunks() -> void:
	if not material:
		push_warning('No material set for the terrain chunks, drawing will not occur.')
		return
	
	for i in range(Shared.last_visible_terrain_chunks.size()):
		Shared.last_visible_terrain_chunks[i].toggle_visible(false)
	Shared.last_visible_terrain_chunks.clear()
	
	var current_chunk_coord_x = roundi(viewer_position.x / chunk_size)
	var current_chunk_coord_y = roundi(viewer_position.y / chunk_size)
	
	for y_offset in range(-chunks_visible_in_view_dst, chunks_visible_in_view_dst):
		for x_offset in range(-chunks_visible_in_view_dst, chunks_visible_in_view_dst):
			var viewed_chunk_coord: Vector2 = Vector2(current_chunk_coord_x + x_offset, current_chunk_coord_y + y_offset)
			
			if (terrain_chunk_dictionary.has(viewed_chunk_coord)):
				var terrain_chunk: TerrainChunk = terrain_chunk_dictionary[viewed_chunk_coord]
				if not terrain_chunk:
					push_warning('Be careful when pushing to this dictionary, anything else than a TerrainChunk will not be processed.')
					break
					
				terrain_chunk.update(viewer_position, max_view_distance)
			else:
				terrain_chunk_dictionary[viewed_chunk_coord] = TerrainChunk.new(viewed_chunk_coord, chunk_size, detail_levels, self, material, max_view_distance)

