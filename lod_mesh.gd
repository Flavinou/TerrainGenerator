extends Node

class_name LODMesh

var terrain_generator: TerrainGenerator

var mesh: Mesh
var has_requested_mesh: bool = false
var has_mesh: bool = false
var lod: int
var update_callback: Callable

func _init(_terrain_generator: TerrainGenerator, _lod: int, _update_callback: Callable):
	terrain_generator = _terrain_generator
	lod = _lod
	update_callback = _update_callback
	

func on_mesh_data_received(_mesh_data: MeshData) -> void:
	mesh = _mesh_data.create_mesh()
	has_mesh = true
	
	update_callback.call_deferred()


func request_mesh(_map_data: MapData) -> void:
	if not terrain_generator:
		push_warning('No Terrain Generator given, requesting mesh cannot occur.')
		return
	
	has_requested_mesh = true
	terrain_generator.request_mesh_data(_map_data, lod, on_mesh_data_received)
