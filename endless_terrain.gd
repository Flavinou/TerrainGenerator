extends Node3D

class_name EndlessTerrain

const MAX_VIEW_DST: float = 450

@export var viewer: Node3D
@export var material: Material

var chunk_size: int
var chunks_visible_in_view_dst: int

var terrain_chunk_dictionary: Dictionary
var last_visible_terrain_chunks: Array[TerrainChunk]


func _init():
	chunk_size = TerrainGenerator.MAP_CHUNK_SIZE - 1
	chunks_visible_in_view_dst = roundi(MAX_VIEW_DST / chunk_size)
	terrain_chunk_dictionary = {}
	last_visible_terrain_chunks = []


#func _ready():
#	if OS.is_debug_build():
#		RenderingServer.set_debug_generate_wireframes(true)
#		get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	update_visible_chunks()


func update_visible_chunks() -> void:
	if not material:
		push_warning('No material set for the terrain chunks, drawing will not occur.')
		return
	
	for i in range(last_visible_terrain_chunks.size()):
		last_visible_terrain_chunks[i].toggle_visible(false)
	last_visible_terrain_chunks.clear()
	
	var current_chunk_coord_x = roundi(viewer.position.x / chunk_size)
	var current_chunk_coord_y = roundi(viewer.position.z / chunk_size)
	
	for y_offset in range(-chunks_visible_in_view_dst, chunks_visible_in_view_dst):
		for x_offset in range(-chunks_visible_in_view_dst, chunks_visible_in_view_dst):
			var viewed_chunk_coord: Vector2 = Vector2(current_chunk_coord_x + x_offset, current_chunk_coord_y + y_offset)
			
			if (terrain_chunk_dictionary.has(viewed_chunk_coord)):
				var terrain_chunk: TerrainChunk = terrain_chunk_dictionary[viewed_chunk_coord]
				if not terrain_chunk:
					push_warning('Be careful when pushing to this dictionary, anything else than a TerrainChunk will not be processed.')
					break
					
				terrain_chunk.update(viewer.position)
				
				if terrain_chunk.visible:
					last_visible_terrain_chunks.append(terrain_chunk)
			else:
				terrain_chunk_dictionary[viewed_chunk_coord] = TerrainChunk.new(viewed_chunk_coord, chunk_size, self, material)

